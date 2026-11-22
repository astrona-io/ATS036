---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Move A Secret From An Environment Variable To A Read-Only Volume

Find the workloads that read a Secret through an environment variable and through a volume, record them, and move one Deployment from the environment variable to a read-only secret volume with file mode 0400. The task and reference solution use a separate pinned kind cluster. The grader checks the Deployment specification, the rollout and the running container with bounded `kubectl exec` requests. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference result passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
