---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Summary

Threats appear at different layers of a cluster, and each layer has its own evidence: the node and the kubelet at the infrastructure layer, application logs, network flow and proxy logs, audit events for data and users, and events, container logs and runtime sensor alerts for workloads. Kubernetes itself keeps only a part of this. It keeps events for one hour by default, container logs on the node, and the audit log only when you configure it.

A container log is a file on the node, written by the container runtime and read through the kubelet. The kubelet rotates it at `containerLogMaxSize` and removes it when the Pod is deleted. After a restart, `kubectl logs --previous` reads the instance that ended, and the Pod status keeps its exit code in `lastState.terminated`. Exit codes above 128 mean a signal, and the reason `OOMKilled` means that the memory limit was exceeded.

By default, no component records connections between Pods. The log of the receiving application can link a request to the sender through the source IP address, but only when no proxy or node address replaces it, and only when the time of the request is also recorded. A NetworkPolicy limits traffic only when the network plugin enforces it.

A missing record has many causes: a source that was never enabled, an audit policy that excludes the request, log rotation, a deleted Pod, a failed collector, a short retention time or a wrong clock. The correct finding is "no record in this source for this period", not "nothing happened". Logs can also hold secrets, so access and retention need limits. The key facts to remember are these:

- Name the layer first, then choose the evidence source for it.
- Read `--previous` logs and the exit code before you delete a failing Pod.
- Source addresses need a time and can be replaced by proxies.
- Absence of a record is not proof of absence of activity.

<!-- astrona:playground:destroy -->
