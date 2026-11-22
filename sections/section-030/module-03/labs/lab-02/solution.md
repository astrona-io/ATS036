---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Find And Limit A Workload That Can Exhaust Its Node Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Find the container without limits

An attacker who runs code in a container can use it to mine coins or to starve other workloads. A resource limit is the most CPU or memory that a container may use. The kubelet passes the limit to the container runtime, and the Linux kernel enforces it with cgroups. A container without limits can take all free CPU and memory of its node. List the limits of every container in the namespace:

```sh
kubectl -n starfleet-036-030-03-02 get pods -o custom-columns=NAME:.metadata.name,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory
```

```text
NAME                        CPU_LIMIT   MEMORY_LIMIT
cruncher-6b597b5f94-pvqvx   <none>      <none>
memory-hog                  100m        32Mi
probe-5977579586-jdglq      200m        128Mi
probe-5977579586-t8rjp      200m        128Mi
shuttle                     100m        32Mi
```

The random suffixes of the Pod names differ in your cluster. A value of `<none>` means that no limit is set. Only the `cruncher` Pod has no CPU limit and no memory limit. Its name starts with the name of the Deployment that created it, and the Deployment is the object to fix, because the ReplicaSet creates every new Pod from the Deployment's template.

## Find the container that was killed

A container that uses more memory than its limit is stopped by the kernel's out-of-memory (OOM) killer. The kubelet then records `OOMKilled` as the reason in the container status and restarts the container. List the restart count and the reason of the last termination:

```sh
kubectl -n starfleet-036-030-03-02 get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason
```

```text
NAME                        RESTARTS   LAST_REASON
cruncher-6b597b5f94-pvqvx   0          <none>
memory-hog                  1          OOMKilled
probe-5977579586-jdglq      0          <none>
probe-5977579586-t8rjp      0          <none>
shuttle                     0          <none>
```

The `memory-hog` container was killed for using too much memory. The limit did its job: the kernel stopped one container instead of letting it take memory from the other Pods on the node. A high restart count shows that the program keeps doing the same thing. That is worth a closer look, but by itself it does not prove an attack.

Record both findings. Save this as `configmap-impact-report.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: impact-report
  namespace: starfleet-036-030-03-02
data:
  unlimitedWorkload: cruncher
  oomKilledPod: memory-hog
```

Apply it:

```sh
kubectl apply -f configmap-impact-report.yaml
```

```text
configmap/impact-report created
```

## Limit the workload

A request is the amount of CPU or memory that the scheduler reserves for a container on a node. A limit is the most that the container may use. The command `kubectl set resources` changes both in the Pod template of the Deployment, and the Deployment controller then replaces the Pod:

```sh
kubectl -n starfleet-036-030-03-02 set resources deployment/cruncher -c worker --requests=cpu=10m,memory=16Mi --limits=cpu=200m,memory=64Mi
kubectl -n starfleet-036-030-03-02 rollout status deployment/cruncher --timeout=120s
```

```text
deployment.apps/cruncher resource requirements updated
Waiting for deployment "cruncher" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "cruncher" rollout to finish: 1 old replicas are pending termination...
deployment "cruncher" successfully rolled out
```

The running Pod did not change. The Deployment created a new Pod with the limits and removed the old one, because every change to the Pod template makes the Deployment roll out new Pods.

## Give the namespace default limits

The next workload that someone creates without limits has the same problem. A LimitRange is a namespaced object that the `LimitRanger` admission plugin of the API server applies to every new Pod. When a container has no requests or limits, the plugin fills in the defaults from the LimitRange before the API server stores the Pod. Save this as `limitrange-container-limits.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: starfleet-036-030-03-02
spec:
  limits:
  - type: Container
    default:
      cpu: 250m
      memory: 128Mi
    defaultRequest:
      cpu: 10m
      memory: 16Mi
```

Apply it:

```sh
kubectl apply -f limitrange-container-limits.yaml
```

```text
limitrange/container-limits created
```

Then check the result. A server-side dry run sends the Pod through admission, including the `LimitRanger` plugin, but the API server stores nothing:

```sh
kubectl -n starfleet-036-030-03-02 run limit-trial --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -o jsonpath='{.spec.containers[0].resources}{"\n"}' -- sleep 1
```

```text
{"limits":{"cpu":"250m","memory":"128Mi"},"requests":{"cpu":"10m","memory":"16Mi"}}
```

The test Pod has no resources in its definition, and the API server answered with the default request and limit from the LimitRange. A LimitRange acts only on new Pods, so the Pods that already run keep their old values. A ResourceQuota, which caps the total resources of a namespace, is the next control when you need to limit the sum of all Pods.

After recording the result, remove this independent lab with `astrona destroy ats-036-lab-030-03-02`.

## Common pitfalls

> [!WARNING]
> - **Changing the Pod instead of the Deployment.** The ReplicaSet creates the next Pod from the template, which still has no limits.
> - **Treating every restart as an attack.** Read the reason: `OOMKilled` means the memory limit was reached, `Error` means the program failed.
> - **Expecting a LimitRange to change running Pods.** The `LimitRanger` admission plugin acts only when the API server receives a new Pod.
> - **Setting only a request.** A request reserves capacity for scheduling. Only a limit caps what the container can use.
