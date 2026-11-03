---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Investigate Secret, Denied And Exec Access From The Audit Log

Generate three kinds of access, find each one in the audit log and bind a report to the audit identifiers.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
