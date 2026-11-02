---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Verify Metadata Audit Records Exclude Secret Payloads

Generate a real Secret read record and verify useful metadata without credential bodies.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-050-01-01" || exit 1
node_name="astro-ats-036-lab-050-01-01-control-plane"
worker_name="astro-ats-036-lab-050-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Keep the provisioned audit Policy at Metadata level for starfleet Secrets. Read the disposable audit-token through the API to generate an event, and record audit-review with level Metadata, resource secrets and result payload-excluded. A ResponseComplete get record for that exact Secret must exist without requestObject or responseObject. Keep audit log storage on the node and API access ready.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
