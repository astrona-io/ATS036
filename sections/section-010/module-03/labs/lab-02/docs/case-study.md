---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The cluster has one control-plane node and one worker. The `probe` Deployment in `starfleet-036-010-03-02` runs two replicas, one on each node. Each `probe` Pod has two containers: `log-agent` and `probe`. The API server writes an audit log at the `Metadata` level for Pods, `pods/exec`, `pods/portforward`, ConfigMaps and Secrets in `starfleet-036-010-03-02`, to `/var/log/training-audit/audit.jsonl` on the control-plane node.

Setup has run one `kubectl exec` request into one `probe` Pod. Link the audit record of that request to the node that runs the Pod and to the ID of the container that the request named. Record the result in ConfigMap `exec-correlation`.
