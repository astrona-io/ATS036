---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Record Interactive Pod Access In The Audit Log

Run a command in a Pod through the API server and bind the audit record of that exec request to a report.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
