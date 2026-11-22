---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Send A Denied Secret Read And Find Its Audit Record

The learner sends a Secret read as a ServiceAccount with `kubectl --as`, finds the audit record of that denied request among other reads of the same Secret, and records its auditID, user and impersonated user in a ConfigMap.

The lab runs in its own pinned kind cluster with one worker. `bootstrap/enable-audit.py` turns on a Metadata audit policy for Secrets in `starfleet-036-050-01-02`, and `bootstrap/setup.sh` seeds the log with an allowed read and a denied read by another ServiceAccount, so the learner must pick the right record. The graders read the audit log on the control plane node and the ConfigMap live; the auditID is random and is never stored in the lab.

Outcomes: `denied-request-sent` (a `ResponseComplete` record of a `get` of `navigation-key` with code 403 and `impersonatedUser.username` `system:serviceaccount:outpost-036-050-01-02:drifter`) and `audit-report` (ConfigMap `denied-read-report` with the auditID and user of that record). Run `testing/smoke.sh` with the lab context selected to check that the starting state fails and the reference solution passes. Static validation is not live evidence; runtime verification remains pending.
