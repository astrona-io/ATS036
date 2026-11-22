---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The namespace `starfleet-036-030-01-02` runs a bare Pod `threat-client` as the ServiceAccount `threat-reader`, and a Deployment `probe` as the ServiceAccount `probe-reader`. Both ServiceAccounts can read Secrets through their own RoleBinding to the Role `secret-reader`. A Secret of the type `kubernetes.io/service-account-token` holds a long-lived token for `threat-reader`. The ConfigMap `incident-ticket` records the UID of the `threat-client` Pod under investigation.

Quarantine the Pod without deleting it, and remove the authority of `threat-reader` while `probe-reader` keeps its access.
