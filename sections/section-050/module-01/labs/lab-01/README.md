---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Verify Metadata Audit Records Exclude Secret Payloads

Generate a real Secret read record and verify useful metadata without credential bodies.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
