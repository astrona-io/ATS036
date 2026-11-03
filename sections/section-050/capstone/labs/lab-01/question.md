---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Investigate Secret, Denied And Exec Access From The Audit Log

Generate three kinds of access, find each one in the audit log and bind a report to the audit identifiers.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-050)"
test "$(kubectl config current-context)" = "kind-ats-036-capstone-050" || exit 1
node_name="astro-ats-036-capstone-050-control-plane"
worker_name="astro-ats-036-capstone-050-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Keep the provisioned audit Policy. Generate three requests and find their records in the audit log on the control plane node.

1. A successful read of the Secret `audit-token` in `starfleet` as the cluster administrator.
2. A denied read of the same Secret as the ServiceAccount `default` in `outpost`, sent with the `--as` option of `kubectl`. The API server must answer `403`.
3. The command `id` run inside the `shuttle` Pod in `starfleet` with `kubectl exec`.

Create the ConfigMap `audit-investigation` in `starfleet` with these keys: `secretAuditID`, `deniedAuditID` and `execAuditID`, each holding the `auditID` of the matching `ResponseComplete` record; `deniedUser` set to `system:serviceaccount:outpost:default`; `execPod` set to `shuttle`; and `secretName` set to `audit-token`. No record may hold a `requestObject` or `responseObject`, and the Secret value must not appear in the log.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
