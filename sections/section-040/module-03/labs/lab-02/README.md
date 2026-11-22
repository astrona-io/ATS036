---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Mount A hostPath Volume Read-Only

Find the Deployment whose container can write to a `hostPath` volume, record the finding in a ConfigMap and change the Pod template so that the volume mount is read-only. The task and reference solution use a separate pinned kind cluster. The `hostPath` points at `/var/lib/training-036-040-03-02`, a directory that the kubelet creates on the node for this lab only. The grader checks the ConfigMap, the Deployment fields and bounded live evidence: a read through the mount, a write that fails with `Read-only file system`, and a check on the node container that the write did not reach the node. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
