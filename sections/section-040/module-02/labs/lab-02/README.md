---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Find A Privileged Pod And Block It With Pod Security Admission

Find the privileged workload and the `hostPID` Pod in a namespace, record them in a ConfigMap, enforce the `baseline` Pod Security Standard with a namespace label and run the workload again without privileged mode. The task and reference solution use a separate pinned kind cluster. The grader reads the live objects and sends its own privileged Pod with a server-side dry run, so it stores nothing. Python 3 is required on the grading host.

The lab changes only labels and objects inside its own namespaces, so its exam scope is `namespace`. The `beacon` Pod adds the capability `NET_BIND_SERVICE`, which the `baseline` standard allows; it is a distractor and must keep running.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference solution passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
