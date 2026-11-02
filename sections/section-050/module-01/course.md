---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Using Kubernetes Audit Logs To Monitor Access

Every request to the Kubernetes API server passes through authentication, authorization and admission. The audit system records the result of these steps in a log, so you can answer who did what, to which object, when, from where, and with what outcome. The audit log is the main source of evidence for access monitoring and for incident investigation in a cluster.

This module teaches how audit records are built, how an audit policy chooses what to record, how the API server writes the log, and how to read the log to find access to sensitive objects such as Secrets. The audit log is not enabled by default. A cluster administrator turns it on with flags on the API server and a policy file.

The four parts are: **The Audit Event Model**, which covers the stages, the levels and the fields of one event; **Writing An Audit Policy**, which covers rule order, matching and the cases a policy silently skips; **API Server Flags, Backends And Troubleshooting**, which covers where the log goes and what breaks when a flag is wrong; and **Reading Audit Records To Monitor Access**, which finds Secret reads and denied requests and checks that the Metadata level keeps payloads out of the log.

## Learning objectives

After this module you can:

- Name the four audit stages and the four audit levels, and say what each records.
- Read the fields of an audit event that identify the user, the action, the object and the result.
- Explain why the first matching policy rule wins and why `pods` does not match `pods/exec`.
- Name the API server flags that enable the log, the rotation settings and the webhook backend.
- Find Secret reads and denied requests in a log file, and confirm that Metadata records contain no request or response body.

## Before you start

You need Kubernetes basics: Pods, Secrets, ServiceAccounts and the commands `kubectl get`, `kubectl exec` and `kubectl auth can-i`. You need to be able to read JSON. You do not need to know how the API server is built.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. A Secret named `audit-token` with disposable data |
| `outpost` | The `drifter` Pod, a BusyBox client |

Audit logging is already on. The log file is `/var/log/training-audit/audit.jsonl` inside the control plane node container, and the policy file is `/etc/kubernetes/training-audit-policy.json`. You read both from your host shell with `podman exec`. Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
