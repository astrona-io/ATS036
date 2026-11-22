---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Starting Environment

The namespace `starfleet-036-050-02-02` runs the Pod `shuttle`, one `probe` replica and the Service `probe` on port 80.

The API server reads its audit policy from `/etc/kubernetes/training-audit-policy.json` on the control plane node and writes events to `/var/log/training-audit/audit.jsonl`. The policy was written to keep the log small. Its first rule drops every Pod subresource request with `level: None`, and the rule that was meant to record interactive access names only `pods`. A `kubectl exec` or `kubectl port-forward` request leaves no record.
