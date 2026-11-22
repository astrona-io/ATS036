---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Link An Exec Audit Record To Its Node And Container

Allow about 10 minutes for the tasks.

Someone opened a session in one `probe` Pod of the `starfleet-036-010-03-02` fleet, and the runtime team needs to know where it ran. Start from the audit record of that `exec` request and link it to the node that runs the Pod and to the ID of the container that received the command.

Solve this question on: `terminal`

## Starting state

The cluster has one control-plane node and one worker. The `probe` Deployment in `starfleet-036-010-03-02` runs two replicas, one on each node. Each `probe` Pod has two containers, `log-agent` and `probe`. The API server writes an audit log at the `Metadata` level for Pods, `pods/exec`, `pods/portforward`, ConfigMaps and Secrets in `starfleet-036-010-03-02`. The log is the file `/var/log/training-audit/audit.jsonl` on the control-plane node. Setup has already run one `kubectl exec` request into one `probe` Pod.

Use the private kubeconfig for `ats-036-lab-010-03-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-03-02)"` and check that the context is `kind-astro-ats-036-lab-010-03-02`. The node containers are `astro-ats-036-lab-010-03-02-control-plane` and `astro-ats-036-lab-010-03-02-worker`.

## Tasks

1. Find the audit record of the `exec` request to a `probe-` Pod. Note its `auditID`, the Pod name from `objectRef.name`, and the container name from the `container=` parameter of its `requestURI`.
2. Find the node that runs that Pod.
3. Find the container ID of the container that the request named. Use the full value of `containerID` from `.status.containerStatuses` of the Pod, including the `containerd://` prefix.
4. Create ConfigMap `exec-correlation` in `starfleet-036-010-03-02` with the keys `auditID`, `podName`, `container`, `nodeName` and `containerID`.

## Constraints

Work only in this lab's namespaces `starfleet-036-010-03-02` and `outpost-036-010-03-02` and its own node containers. Do not delete, restart or change the `probe` Pods: the container ID changes when a container restarts. Do not change the audit policy or the audit log.

## How the answer is checked

Each check gives one point: the correlation names a real `pods/exec` audit record, the Pod that received it and the container named in the request; the correlation names the node that runs that Pod and the container ID of that container. The grader compares the ConfigMap with the live audit log and the live Pod status.
