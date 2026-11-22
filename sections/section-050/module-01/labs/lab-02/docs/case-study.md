---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Starting Environment

The namespace `starfleet-036-050-01-02` holds the disposable Secret `navigation-key`. The namespace `outpost-036-050-01-02` holds the ServiceAccount `drifter`, which has no permissions.

The API server writes audit events to `/var/log/training-audit/audit.jsonl` on the control plane node. The audit policy records requests for Secrets in `starfleet-036-050-01-02` at the `Metadata` level and drops every other request. The log already holds an allowed read of `navigation-key` by the cluster administrator and a denied read by the `default` ServiceAccount of `outpost-036-050-01-02`.
