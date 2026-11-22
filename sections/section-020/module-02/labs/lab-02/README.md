---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Count Failed Logins In An Application Log

Count the failed logins in the log of an application Pod, name the user and source address behind the repeated failures, and record whether a login from that address succeeded afterwards. The task and reference solution use a separate pinned kind cluster. The grader compares the report with the live container log, read with `kubectl logs`. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference result passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
