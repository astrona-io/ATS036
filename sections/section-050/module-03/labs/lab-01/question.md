---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Record The Audit Retention Settings And Log File Protection

Read the live audit retention flags and the log file mode from the control plane node and record them.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-050-03-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-03-01)"` and check that the context is `kind-astro-ats-036-lab-050-03-01`.

## Tasks

1. Read the API server static Pod manifest on this environment’s control plane. Identify its audit policy path, log path and rotation flags.
2. Create `audit-retention` in `starfleet-036-050-03-01` with keys `policyFile`, `logPath`, `maxAge`, `maxBackup`, `maxSize` and `logMode`. Copy the configured values and the actual log file permission mode.
3. Verify that the log contains audit records and the API remains ready. Preserve the staged policy, paths, rotation settings and file permissions.

## Constraints

Work only in this lab’s namespaces `starfleet-036-050-03-01` and `outpost-036-050-03-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The report matches live audit paths, rotation flags and file mode. The grader reads live resources and evidence; it does not award points for preserving the starting state.
