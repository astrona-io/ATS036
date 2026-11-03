---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Guided Practice: Report A Risky Pod Specification

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-playground-020-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Pod `suspect-pod` runs a container with extra privileges and mounts a directory of the node. Pod `login-service` and the healthy probe application are separate from that evidence Pod.

Inspect the relevant evidence:

```sh
kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}'
kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.volumes[*].hostPath.path}{"\n"}'
```

The first command prints the `privileged` setting of the container. The second prints the node directory that the Pod mounts. Both settings come from the Pod specification, which is the record of what the Pod is allowed to do. Preserve the evidence Pod so the recorded report can be checked against the runtime.

Save this as `configmap-pod-risk-report.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pod-risk-report
  namespace: starfleet
data:
  pod: suspect-pod
  privileged: 'true'
  hostPath: /etc
```

Apply the required change:

```sh
kubectl apply -f configmap-pod-risk-report.yaml
```

## Verify The Result

Observe the actual result.

```sh
kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}'
kubectl -n starfleet get configmap pod-risk-report -o jsonpath='{.data}{"\n"}'
```

Leave Pod `suspect-pod` running. Read its specification. Create ConfigMap `pod-risk-report` with `pod: suspect-pod`, `privileged` matching the container `securityContext`, and `hostPath` matching the node directory that the Pod mounts. Do not delete or change the evidence Pod.

## Common pitfalls

> [!WARNING]
> Read the setting from the Pod specification, not from the image name or the Pod name. Preserve the evidence Pod. The value in the ConfigMap is a string, so write `'true'` in quotes.
