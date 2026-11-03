---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and three Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet namespace. Setup has produced two events: the threat-reader ServiceAccount asked for the audit-token Secret and was denied, and one `kubectl exec` ran a command in a probe Pod. Nothing has been reported or contained yet.

Report a denied Secret request and an exec into a probe Pod from the audit log, then quarantine the Pod without deleting it.
