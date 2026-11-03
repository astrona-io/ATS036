---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Auditing Interactive Access To Pods

Some of the most important actions in a cluster are not objects that are created or changed. A user who runs `kubectl exec` opens a shell inside a container, and a user who runs `kubectl port-forward` opens a tunnel to a Pod. The API server treats these actions as requests to subresources of a Pod, and an audit policy has to name those subresources on purpose.

This module teaches how subresource requests appear in the audit log, how to write policy rules that record them, and how to read an exec record to answer who ran which command in which Pod. It also explains what the audit log does not hold, which is the output of the command.

The three parts are: **Subresources In Audit Policy Rules**, which explains why the resource `pods` does not match `pods/exec`; **Recording And Reading Exec Events**, which runs a command in a Pod and finds the record; and **Choosing Rules And Levels For Interactive Access**, which covers rule order, filters and the limits of the evidence.

## Learning objectives

After this module you can:

- Name the Pod subresources that carry interactive access and say why a policy must list them.
- Find an exec request in the audit log and read the user, the Pod, the container and the command from it.
- Explain why the verb of an exec request is not a reliable filter.
- State what an exec record proves and what it does not prove.

## Before you start

You need Pods, namespaces and the commands `kubectl get` and `kubectl exec`. You need to know that the audit log is a file of JSON events written by the API server, and that a policy decides which requests are written.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. A Secret named `audit-token` with disposable data |
| `outpost` | The `drifter` Pod, a BusyBox client |

Audit logging is on. The log file is `/var/log/training-audit/audit.jsonl` inside the control plane node container, and the policy file is `/etc/kubernetes/training-audit-policy.json`. You read both from your host shell with `podman exec`. The policy in this playground records `pods/exec`, `pods/portforward` and `pods/log` in the `starfleet` namespace.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
