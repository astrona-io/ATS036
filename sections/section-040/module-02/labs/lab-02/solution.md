---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Find A Privileged Pod And Block It With Pod Security Admission Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A privileged container is a container with `privileged: true` in its `securityContext`. The container runtime gives it all Linux capabilities and the devices of the node, and it skips the default seccomp and AppArmor restrictions. Dropped capabilities and `allowPrivilegeEscalation: false` do not limit it. A Pod with `hostPID: true` is a second kind of risk: its processes share the process namespace of the node, so they can see and signal every process on the node. Neither setting belongs in an application namespace.

## Find the Pods with extra rights

The stored Pod objects hold the answer, so start with the API server, not with the containers. Print the fields that add rights for every Pod in the namespace. A field that is not set prints as `<none>`:

```sh
kubectl -n starfleet-036-040-02-02 get pods -o custom-columns='POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,HOSTPID:.spec.hostPID,ADDED:.spec.containers[*].securityContext.capabilities.add'
```

<!-- CAPTURE: l2-find-pods -->

One Pod of `telemetry-agent` shows `true` in the `PRIVILEGED` column, and `node-inspector` shows `true` in the `HOSTPID` column. The `beacon` Pod adds the capability `NET_BIND_SERVICE`. That capability only lets a process bind to a port below 1024, and the `baseline` Pod Security Standard allows it, so `beacon` is not a finding.

The Pod name of `telemetry-agent` ends in a random suffix, because the Deployment controller creates it through a ReplicaSet. A deleted Pod comes back with the same settings, so the fix belongs in the Deployment. Read the container name from the Pod template of the Deployment:

```sh
kubectl -n starfleet-036-040-02-02 get deployments -o custom-columns='DEPLOYMENT:.metadata.name,CONTAINER:.spec.template.spec.containers[*].name,PRIVILEGED:.spec.template.spec.containers[*].securityContext.privileged'
```

<!-- CAPTURE: l2-find-deployments -->

The Deployment `telemetry-agent` has one container, `agent`, with `privileged: true`. The object is one half of the evidence. The other half is the running process. Read the effective capabilities of process 1 in that container:

```sh
kubectl -n starfleet-036-040-02-02 exec deploy/telemetry-agent -- grep CapEff /proc/1/status
```

<!-- CAPTURE: l2-capeff-before -->

`CapEff` is a hexadecimal bit mask of the capabilities that the kernel lets the process use. In a privileged container every bit of a known capability is set, so the value is much larger than the default set of a normal container.

## Record the finding

Write the names into a ConfigMap, so that the finding is stored next to the workload. Save this as `configmap-privilege-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: privilege-finding
  namespace: starfleet-036-040-02-02
data:
  privilegedWorkload: telemetry-agent
  privilegedContainer: agent
  hostPIDPod: node-inspector
```

Apply it:

```sh
kubectl apply -f configmap-privilege-finding.yaml
```

<!-- CAPTURE: l2-apply-finding -->

The finding names the Deployment, not the Pod, because the Pod name changes each time the ReplicaSet controller creates a new Pod.

## Enforce the baseline standard

Pod Security Admission is the admission controller built into the API server. A namespace label chooses a Pod Security Standard and a mode. The `baseline` standard forbids privileged containers, host namespaces such as `hostPID`, `hostPath` volumes and capabilities outside a short allowed list. The `enforce` mode makes the API server reject a new Pod that breaks the standard. Label the namespace:

```sh
kubectl label namespace starfleet-036-040-02-02 pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=latest
```

<!-- CAPTURE: l2-label -->

kubectl prints warnings before the confirmation. When the enforce label changes, the API server checks the Pods that already run in the namespace against the new standard and returns a warning for each Pod that would now be rejected. The warnings name the `telemetry-agent` Pod with `privileged` and `node-inspector` with host namespaces. `beacon` is not named, because `NET_BIND_SERVICE` is allowed. The label does not stop these Pods. List them:

```sh
kubectl -n starfleet-036-040-02-02 get pods
```

<!-- CAPTURE: l2-pods-after-label -->

Every Pod still runs. Pod Security Admission acts only on new requests, so the existing Pods stay until you replace them.

## Prove that a privileged Pod is rejected

A server-side dry run sends the object through every admission step of the API server, but the API server does not store it. The test Pod below has no `namespace` field, so `-n` chooses the namespace.

Save this as `pod-privileged-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-check
spec:
  restartPolicy: Never
  containers:
  - name: main
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

Send it with a server-side dry run:

```sh
kubectl -n starfleet-036-040-02-02 create --dry-run=server -f pod-privileged-check.yaml
```

<!-- CAPTURE: l2-dry-run-privileged -->

The API server rejects the Pod with `forbidden`. The message names the standard and version, `baseline:latest`, and the field of the container that breaks it. Pod Security Admission did this check, so no container process ever started.

## Run the workload without privileged mode

The `telemetry-agent` Deployment still has `privileged: true` in its Pod template. When the Deployment controller rolls out a new Pod from that template, the API server rejects the Pod, and the rollout stalls. Fix the template. Save this as `deployment-telemetry-agent.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetry-agent
  namespace: starfleet-036-040-02-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: telemetry-agent
  template:
    metadata:
      labels:
        app: telemetry-agent
    spec:
      terminationGracePeriodSeconds: 2
      containers:
      - name: agent
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
```

Apply it:

```sh
kubectl apply -f deployment-telemetry-agent.yaml
```

<!-- CAPTURE: l2-apply-deployment -->

Then wait for the new Pod:

```sh
kubectl -n starfleet-036-040-02-02 rollout status deployment/telemetry-agent --timeout=180s
```

<!-- CAPTURE: l2-rollout -->

The Deployment controller created a new ReplicaSet, and Pod Security Admission accepted its Pod because the template now meets `baseline`. Check the process of the new Pod:

```sh
kubectl -n starfleet-036-040-02-02 exec deploy/telemetry-agent -- grep CapEff /proc/1/status
```

<!-- CAPTURE: l2-capeff-after -->

`CapEff` is now the smaller default set that the container runtime gives a normal container. The process lost the rights that privileged mode added.

The `node-inspector` Pod is a bare Pod with no controller, and the task says it is not needed. Delete it:

```sh
kubectl -n starfleet-036-040-02-02 delete pod node-inspector
```

<!-- CAPTURE: l2-delete-inspector -->

Run the first check again to see the namespace after the change:

```sh
kubectl -n starfleet-036-040-02-02 get pods -o custom-columns='POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,HOSTPID:.spec.hostPID,ADDED:.spec.containers[*].securityContext.capabilities.add'
```

<!-- CAPTURE: l2-find-pods-after -->

No Pod shows `true` in the `PRIVILEGED` or `HOSTPID` columns, and the API server rejects any new Pod that would. Only `beacon` still adds a capability, and that capability is allowed by `baseline`. The `baseline` standard does not require a non-root user, dropped capabilities or a seccomp profile; the `restricted` standard does, and it is the next step for this namespace once its workloads meet it.

When you are done, remove the lab with `astrona destroy ats-036-lab-040-02-02`.

## Common pitfalls

> [!WARNING]
> - **Expecting the label to stop running Pods.** Pod Security Admission only prints warnings for existing Pods. Replace or delete them yourself.
> - **Fixing the Pod instead of the Deployment.** A deleted Pod comes back from the same Pod template. Change the template.
> - **Using `warn` or `audit` instead of `enforce`.** Both modes still create the privileged Pod.
> - **Treating every added capability as a finding.** `baseline` allows a short list, such as `NET_BIND_SERVICE`. Judge each one.
> - **Enforcing `restricted` before the workloads are ready.** New Pods that run as root or keep their capabilities are then rejected, and rollouts stall.
