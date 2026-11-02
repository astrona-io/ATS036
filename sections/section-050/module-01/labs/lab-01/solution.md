---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Verify Metadata Audit Records Exclude Secret Payloads Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-050-01-01" || exit 1
node_name="astro-ats-036-lab-050-01-01-control-plane"
worker_name="astro-ats-036-lab-050-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Keep the provisioned audit Policy at Metadata level for starfleet Secrets. Read the disposable audit-token through the API to generate an event, and record audit-review with level Metadata, resource secrets and result payload-excluded. A ResponseComplete get record for that exact Secret must exist without requestObject or responseObject. Keep audit log storage on the node and API access ready.

Save this as `configmap-audit-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-review
  namespace: starfleet
data:
  level: Metadata
  resource: secrets
  result: payload-excluded
```

Apply the scoped correction:

```sh
kubectl -n starfleet get secret audit-token -o name
kubectl apply -f configmap-audit-review.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet get configmaps
kubectl -n starfleet get deployment probe -o yaml
```

Generate a real Secret read record and verify useful metadata without credential bodies. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-050-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
