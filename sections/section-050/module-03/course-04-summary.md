---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Summary

The API server writes audit events to a file and rotates it with three flags. `--audit-log-maxsize` sets the size in megabytes at which a new file starts, `--audit-log-maxbackup` sets how many rotated files remain and `--audit-log-maxage` sets how many days a rotated file remains. The largest disk use is the size limit times the number of files. On a busy cluster, the size and backup limits remove evidence long before the age limit does.

In a kubeadm or `kind` cluster, the flags are in the `kube-apiserver` static Pod manifest on the control plane node. Reading them from that file shows the real settings. The log is a sensitive file because it lists users, groups, source addresses and object names, even when no Secret value is present. The owner, the mode of the file and the mode of its directory decide who can read, change or delete it, and a `root` user on the node can always do all three.

A copy of the events on another system gives stronger evidence. The webhook backend sends events to an HTTPS collector in `batch`, `blocking` or `blocking-strict` mode. `batch` protects availability and can drop events. `blocking-strict` protects the log and can stop API requests when the collector fails. A retention policy states the period, the storage, the location of the long-term copy and the behavior during a failure.

Key facts:

- Rotation deletes the oldest rotated file when a limit is reached.
- `maxbackup=0` and `maxage=0` mean no limit.
- Read the live flags from the static Pod manifest.
- Read the file mode with `stat`, and check the directory too.
- Use `json` format for parsing tools.



## Independent live assessment

Prepare with [Verify Delivery To An Audit Webhook](course-03a-verify-audit-webhook-delivery.md). [Deliver Audit Metadata Outside The Control Plane](labs/lab-02/question.md) uses its own qemu environment. A fresh audit event reaches the authenticated TLS collector outside the control-plane container; Only the scoped namespace is collected and Secret bodies remain absent.

<!-- astrona:playground:destroy -->
