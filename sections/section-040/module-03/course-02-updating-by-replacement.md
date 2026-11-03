---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Updating By Replacement

Every manual change to a running container creates a container that no reviewed file describes. Kubernetes already has a safer path: change the definition and let the controller replace the containers. This part shows how a Deployment does that, proves that a manual change does not survive, and shows how to roll a bad change back.

## Controllers, ReplicaSets and Pod templates

A Deployment holds a Pod template. The Deployment controller creates a ReplicaSet for each version of that template, and the ReplicaSet creates the Pods. When you change the template, the controller creates a new ReplicaSet, starts new Pods in it and scales the old ReplicaSet down. The old Pods are deleted, not edited. The new Pods start from the image and the settings of the new template, so nothing a person or an attacker wrote into an old container carries over.

Not every field starts a rollout. A change to the template, such as an environment variable, an image or a security context, creates a new ReplicaSet. A change to the replica count does not.

## Show that a manual change disappears

Select the playground cluster and write a file into one of the running `probe` Pods:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-040-03)"
kubectl -n starfleet exec deploy/probe -- touch /tmp/manual-change
kubectl -n starfleet exec deploy/probe -- ls /tmp
```

The listing shows `manual-change`. The Pod is now different from its definition, and nothing in the Deployment records that. Now change the template. The `VERSION` environment variable is part of it:

```sh
kubectl -n starfleet set env deployment/probe VERSION=v2
kubectl -n starfleet rollout status deployment/probe --timeout=120s
```

The `rollout status` command waits until all new Pods are ready and all old Pods are gone. List the Pods and the ReplicaSets:

```sh
kubectl -n starfleet get pods -l app=probe
kubectl -n starfleet get replicaset -l app=probe
```

The Pods have new names. The newest ReplicaSet has two Pods, and the older ReplicaSet is scaled to zero but still exists. Check the new Pod and ask the service for its version:

```sh
kubectl -n starfleet exec deploy/probe -- ls /tmp
kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe/ready
```

The first command no longer shows `manual-change`. The second command prints a line that starts with `version=v2`, which the Python server in the Pod builds from the environment variable. The `shuttle` Pod sent the request to the `probe` Service, which chose one of the new Pods.

## Make the new Pods immutable at the same time

A rollout is the right moment to tighten the Pod. The same template change can add a read-only root filesystem. The `probe` container writes temporary marker files under `/tmp`, so it needs an `emptyDir` volume there. Save this as `probe-patch.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: probe
          securityContext:
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

Apply it as a strategic merge patch, which adds the new entries to the existing lists by name:

```sh
kubectl -n starfleet patch deployment probe --patch-file probe-patch.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=120s
```

Test the new Pods:

```sh
kubectl -n starfleet exec deploy/probe -- sh -c 'echo denied > /root-file'
kubectl -n starfleet exec deploy/probe -- sh -c 'printf ok > /tmp/check; cat /tmp/check'
```

The first command fails with `Read-only file system`. The second command prints `ok`. The Deployment controller, not the container, made this change, and it did so by replacement.

## Read the history and roll back

The Deployment keeps its older ReplicaSets so a change can be undone:

```sh
kubectl -n starfleet rollout history deployment/probe
```

The output lists the revisions. A rollback starts a rollout back to the template of an earlier revision:

```sh
kubectl -n starfleet rollout undo deployment/probe
kubectl -n starfleet rollout status deployment/probe --timeout=120s
```

A rollback is also a replacement. It creates new Pods from the older template; it does not repair the old ones. After the rollback, apply the patch again, so that the later parts start from the hardened state:

```sh
kubectl -n starfleet patch deployment probe --patch-file probe-patch.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=120s
```

This part showed how to change a workload without touching a container. The remaining question is how to know that the containers that run are the ones you approved.

## Common pitfalls

> [!WARNING]
> - **Fixing a Pod with `kubectl exec`.** The fix lasts until the next restart or rollout, and nobody reviews it. Change the template instead.
> - **Editing a bare Pod.** A Pod without a controller is not replaced automatically. Use a Deployment, StatefulSet or DaemonSet for long-running workloads.
> - **Expecting a replica change to start a rollout.** Only changes to the Pod template create a new ReplicaSet.
> - **Forgetting the writable path.** A new read-only root filesystem breaks an application that writes under `/tmp`. Add the `emptyDir` volume in the same change.
> - **Reading a rollback as a repair.** A rollback replaces Pods with the earlier template. It does not undo changes made to data in volumes.
