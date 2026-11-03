---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Record The Audit Retention Settings And Log File Protection

Read the live audit retention flags and the log file mode from the control plane node and record them.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-03-01)"
test "$(kubectl config current-context)" = "kind-ats-036-lab-050-03-01" || exit 1
node_name="astro-ats-036-lab-050-03-01-control-plane"
worker_name="astro-ats-036-lab-050-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Keep the provisioned audit configuration. Read the audit flags from the `kube-apiserver` static Pod manifest on the control plane node and the permission mode of the audit log file. Create the ConfigMap `audit-retention` in `starfleet` with `policyFile`, `logPath`, `maxAge`, `maxBackup`, `maxSize` and `logMode`. The values must match the live manifest and the live file: `policyFile` and `logPath` are the paths from the flags, `maxAge` is in days, `maxBackup` is a count of files, `maxSize` is in megabytes and `logMode` is the octal mode printed by `stat -c %a`. Do not change the API server.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
