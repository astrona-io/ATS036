---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Report And Contain Suspicious Behavior From Audit Evidence

Report a denied Secret request and an exec into a probe Pod from the audit log, then quarantine the Pod without deleting it.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
