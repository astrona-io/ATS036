---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Enforce A Read-Only Root Filesystem With A ValidatingAdmissionPolicy

Reject new Pods without `readOnlyRootFilesystem: true` in one namespace with a ValidatingAdmissionPolicy and a ValidatingAdmissionPolicyBinding, and keep a second namespace open. The task and reference solution use a separate pinned kind cluster. The grader reads the policy and binding objects and sends its own Pods to the API server with server-side dry runs, so it stores nothing. Python 3 is required on the grading host.

The lab creates cluster-scoped objects, so its exam scope is `cluster`. Both object names carry the lab suffix `036-040-01-02`, and the binding selects only namespaces with the label `immutability=enforced`, so the policy does not reach other labs on a shared exam cluster.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference solution passes. Each wait and request is bounded; the binding can take a few seconds to become active, and the retry loop allows two minutes. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
