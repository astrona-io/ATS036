---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Record Interactive Pod Access In The Audit Log

Run a command in a Pod through the API server and bind the audit record of that exec request to a report.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-02-01)"
test "$(kubectl config current-context)" = "kind-ats-036-lab-050-02-01" || exit 1
node_name="astro-ats-036-lab-050-02-01-control-plane"
worker_name="astro-ats-036-lab-050-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Keep the provisioned audit Policy as it is: it records `pods/exec` in `starfleet` at the `Metadata` level. Run the command `id` inside the `shuttle` Pod in `starfleet` through the API server, so that an exec record exists. Create the ConfigMap `audit-exec` in `starfleet` with `resource` set to `pods`, `subresource` set to `exec`, `podName` set to `shuttle`, `command` set to `id` and `level` set to `Metadata`. The audit log must contain the record of that exec request without `requestObject` or `responseObject`. Keep API access ready.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
