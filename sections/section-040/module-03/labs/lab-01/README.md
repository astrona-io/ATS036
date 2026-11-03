---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Update A Workload By Replacement With A Read-Only Root

Replace the Pods of a Deployment through its template so that they run version v2 with a read-only root filesystem and a writable temporary path. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
