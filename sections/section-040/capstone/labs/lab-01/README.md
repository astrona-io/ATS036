---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Harden A Workload And Enforce A Read-Only Root Filesystem Policy

Harden an existing Deployment and add an admission rule that rejects new Pods with a writable root filesystem in one namespace. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
