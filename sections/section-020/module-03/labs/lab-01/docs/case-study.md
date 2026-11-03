---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

The namespace `starfleet` holds Secret `db-credentials` and two ServiceAccounts, `reporter` and `auditor`. One of them can read Secrets. Pod `data-client` and the healthy probe application are separate from that evidence.

Do not change any RBAC object. Find the ServiceAccount that can `get` Secrets in `starfleet`. Create ConfigMap `access-finding` with `subject` set to its full user name (`system:serviceaccount:starfleet:<name>`), `verb: get`, `resource: secrets` and `binding` set to the name of the RoleBinding that grants the access.
