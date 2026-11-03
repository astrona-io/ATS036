---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Guided Practice: Record Interactive Pod Access In The Audit Log

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-050-02)"
test "$(kubectl config current-context)" = "kind-ats-036-playground-050-02" || exit 1
node_name="astro-ats-036-playground-050-02-control-plane"
worker_name="astro-ats-036-playground-050-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Keep the provisioned audit Policy as it is: it records `pods/exec` in `starfleet` at the `Metadata` level. Run the command `id` inside the `shuttle` Pod in `starfleet` through the API server, so that an exec record exists. Create the ConfigMap `audit-exec` in `starfleet` with `resource` set to `pods`, `subresource` set to `exec`, `podName` set to `shuttle`, `command` set to `id` and `level` set to `Metadata`. The audit log must contain the record of that exec request without `requestObject` or `responseObject`. Keep API access ready.

Run the command in the `shuttle` Pod. The API server audits this request:

```sh
kubectl -n starfleet exec shuttle -- id
```

Save this as `configmap-audit-exec.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-exec
  namespace: starfleet
data:
  resource: pods
  subresource: exec
  podName: shuttle
  command: id
  level: Metadata
```

Apply it:

```sh
kubectl apply -f configmap-audit-exec.yaml
```

## Verify The Result

Check the report and look for the exec request in the log on the control plane node:

```sh
kubectl -n starfleet get configmap audit-exec -o yaml
podman exec "$node_name" grep -c 'pods/shuttle/exec' /var/log/training-audit/audit.jsonl
```

The count is the number of log lines that name the exec path of the `shuttle` Pod. It must be greater than `0`. The record holds the command in `requestURI`, not the output of the command. A matching ConfigMap alone does not prove that the request was audited.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
