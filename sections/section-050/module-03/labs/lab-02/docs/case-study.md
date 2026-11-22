---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster. The kube-apiserver sends audit events to `audit-collector.service`, an HTTPS receiver on `127.0.0.1:8443` outside its Pod. The webhook file `/etc/kubernetes/audit/webhook.yaml` sends the wrong token, and the policy `/etc/kubernetes/audit/policy.yaml` records nothing. The collector writes the events it accepts to `/var/log/audit-collector/events.jsonl`.
