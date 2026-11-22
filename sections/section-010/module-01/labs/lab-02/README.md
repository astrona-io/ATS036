---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Quarantine A Suspicious Pod Without Deleting It

Capture evidence from a running Pod with an ephemeral container, then quarantine the Pod by changing the labels that its Deployment and Service select.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence.
