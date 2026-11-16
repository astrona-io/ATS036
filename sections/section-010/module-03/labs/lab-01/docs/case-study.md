---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet-036-010-03-01 namespace. Setup has already run one `kubectl exec` into a probe Pod. The required result has not been configured.

Find the audit record of an interactive command run in a probe Pod and bind the finding to the identity and audit identifier.
