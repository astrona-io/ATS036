---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Retaining And Protecting Audit Logs

An audit log helps an investigation only if it still exists, has not been changed and can be read by the right people only. The API server writes the log to a file with rotation limits, and a node administrator can read, copy or delete that file. This module covers how rotation decides how long evidence lives, how to protect the log file, and how to forward events off the node with the webhook backend.

The three parts are: **Rotation Flags And Disk Use**, which explains `--audit-log-maxage`, `--audit-log-maxbackup` and `--audit-log-maxsize` and the amount of evidence they keep; **Protecting The Log File**, which covers the file mode, the owner and what an event reveals; and **Forwarding And Retention Policy**, which covers the webhook backend and the choice between losing events and losing availability.

## Learning objectives

After this module you can:

- Read the audit flags from the `kube-apiserver` static Pod manifest.
- Work out the largest amount of disk the log uses and the shortest period it can cover.
- Check the mode and the owner of the audit log file on a node.
- Explain the `batch`, `blocking` and `blocking-strict` modes of the webhook backend.

## Before you start

You need the basics of the audit system: events, levels and the audit policy file. You need to know that the API server on a `kind` cluster runs as a static Pod, which the kubelet starts from a manifest file in `/etc/kubernetes/manifests`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. A Secret named `audit-token` with disposable data |
| `outpost` | The `drifter` Pod, a BusyBox client |

Audit logging is on. The log file is `/var/log/training-audit/audit.jsonl` inside the control plane node container, and the policy file is `/etc/kubernetes/training-audit-policy.json`. You read both from your host shell with `podman exec`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
