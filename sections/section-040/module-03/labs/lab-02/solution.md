---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Mount A hostPath Volume Read-Only Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A `hostPath` volume mounts a file or directory of the node into a container. The container then reads and writes real node files, outside its own filesystem. A read-only root filesystem does not protect these files, because the mount is a different filesystem. The field that decides whether the container may write is `readOnly` on the `volumeMount` of the container.

## Find the writable mount

Start with the volumes. This command prints each Deployment of the namespace with the node paths of its `hostPath` volumes. A Deployment without a `hostPath` volume shows an empty second column:

```sh
kubectl -n starfleet-036-040-03-02 get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.volumes[*].hostPath.path}{"\n"}{end}'
```

```text
beacon	
collector	/var/lib/training-036-040-03-02
relay	/var/lib/training-036-040-03-02
```

The `collector` and `relay` Deployments both mount `/var/lib/training-036-040-03-02`. The `beacon` Deployment has no `hostPath` volume. A volume alone does not say whether the container can write, so print the volume mounts of the two candidates:

```sh
kubectl -n starfleet-036-040-03-02 get deployment collector relay -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].volumeMounts}{"\n"}{end}'
```

```text
collector	[{"mountPath":"/host-data","name":"node-data"}]
relay	[{"mountPath":"/host-data","name":"node-data","readOnly":true}]
```

The `relay` mount has `"readOnly":true`. The `collector` mount has no `readOnly` field, and the default is `false`, so the `collector` container can write. The volume of the `collector` is named `node-data`. You can prove the write before you fix it. Use a separate test file, so that `approved.txt` stays unchanged:

```sh
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- sh -c 'echo written-by-pod > /host-data/write-test && cat /host-data/write-test'
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- rm /host-data/write-test
```

```text
written-by-pod
```

The first command prints `written-by-pod`. The file was in `/var/lib/training-036-040-03-02` on the node until the second command removed it. Any process in the `collector` container could change the settings file that `relay` reads in the same way.

## Record the finding

Write the three facts into a ConfigMap. Save this as `configmap-hostpath-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hostpath-finding
  namespace: starfleet-036-040-03-02
data:
  workload: collector
  volume: node-data
  path: /var/lib/training-036-040-03-02
```

Apply it:

```sh
kubectl apply -f configmap-hostpath-finding.yaml
```

```text
configmap/hostpath-finding created
```

Then check the result:

```sh
kubectl -n starfleet-036-040-03-02 get configmap hostpath-finding -o jsonpath='{.data}{"\n"}'
```

```text
{"path":"/var/lib/training-036-040-03-02","volume":"node-data","workload":"collector"}
```

## Make the mount read-only

The fix goes into the Pod template, not into the running Pod. A change to the template makes the Deployment controller create a new ReplicaSet, which starts a new Pod with the new mount and removes the old one. The `collector` only reads `approved.txt`, so it needs the volume but not write access. Keep the volume and add `readOnly: true` to its mount. Save this as `deployment-collector.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: collector
  namespace: starfleet-036-040-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: collector
  template:
    metadata:
      labels:
        app: collector
    spec:
      terminationGracePeriodSeconds: 2
      containers:
      - name: collector
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - while true; do cat /host-data/approved.txt 2>/dev/null; sleep 30; done
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 64Mi
        volumeMounts:
        - name: node-data
          mountPath: /host-data
          readOnly: true
      volumes:
      - name: node-data
        hostPath:
          path: /var/lib/training-036-040-03-02
          type: DirectoryOrCreate
```

Apply it:

```sh
kubectl apply -f deployment-collector.yaml
```

```text
deployment.apps/collector configured
```

Then wait for the rollout:

```sh
kubectl -n starfleet-036-040-03-02 rollout status deployment/collector --timeout=180s
```

```text
Waiting for deployment "collector" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "collector" rollout to finish: 1 old replicas are pending termination...
deployment "collector" successfully rolled out
```

The `rollout status` command returns when the new Pod is available and the old ReplicaSet has no Pods left. From now on, the kubelet mounts the node directory read-only into the `collector` container.

## Check the read and the write

The fix must keep the read and remove the write. Read the settings file through the mount first:

```sh
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- cat /host-data/approved.txt
```

```text
approved-settings-v1
```

The new Pod still prints `approved-settings-v1`. Now try the write again. This command is meant to fail, so run it on its own and not in a script that stops on the first error:

```sh
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- sh -c 'echo changed > /host-data/write-test'
```

```text
sh: can't create /host-data/write-test: Read-only file system
command terminated with exit code 1
```

The shell in the container cannot create the file, and the error ends in `Read-only file system`. The last line comes from kubectl: the shell exited with code 1. The Linux kernel refused the write, because the kubelet mounted the volume read-only. If the write still works, the command reached the old Pod before it was gone; wait a few seconds and run it again. The grader runs the same read and write in every `collector` Pod and then checks on the node that its test file is not in `/var/lib/training-036-040-03-02`.

You now know how to find a writable `hostPath` mount from the Pod template, and that `readOnly: true` on the `volumeMount` removes the write but keeps the read. The `hostPath` volume still ties the Pod to one node and still exposes the node directory for reading, so the narrowest path and a read-only mount are the least you need when a workload cannot do without one.

When you are done, remove the lab with `astrona destroy ats-036-lab-040-03-02`.

## Common pitfalls

> [!WARNING]
> - **Reading only the volumes.** The `volumes` list shows that a `hostPath` exists. Only the `volumeMount` of each container shows whether that container can write.
> - **Missing `readOnly` means writable.** A mount without the field is read-write.
> - **Removing the volume.** The `collector` must still read `approved.txt`. Removing the `hostPath` breaks the workload; a read-only mount keeps it working.
> - **Changing the running Pod.** A Pod's volume mounts cannot be changed in place. Change the Deployment template and let the controller replace the Pod.
> - **Trusting `readOnlyRootFilesystem`.** That setting protects only the root filesystem of the container, not its volumes.
