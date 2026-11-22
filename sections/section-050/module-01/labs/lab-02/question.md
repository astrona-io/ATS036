---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Send A Denied Secret Read And Find Its Audit Record

Allow about 8 minutes for the tasks.

The `drifter` in `outpost-036-050-01-02` must never read the `navigation-key` of the `starfleet-036-050-01-02` namespace. Prove that the API server denies such a read and that the audit log shows who sent it.

Solve this question on: `terminal`

## Starting state

The Secret `navigation-key` is in `starfleet-036-050-01-02`. The ServiceAccount `drifter` is in `outpost-036-050-01-02` and has no permissions. The API server writes audit events to `/var/log/training-audit/audit.jsonl` on the control plane node, with a policy that records Secret requests in `starfleet-036-050-01-02` at the `Metadata` level. The log already holds other reads of `navigation-key`.

Use the private kubeconfig for `ats-036-lab-050-01-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-02)"` and check that the context is `kind-astro-ats-036-lab-050-01-02`. The control plane node container is `astro-ats-036-lab-050-01-02-control-plane`.

## Tasks

1. As the cluster administrator, send a `get` request for the Secret `navigation-key` in `starfleet-036-050-01-02` with impersonation of the ServiceAccount `drifter` of `outpost-036-050-01-02` (`kubectl --as=system:serviceaccount:outpost-036-050-01-02:drifter`). The API server must deny it.
2. Find the `ResponseComplete` audit record of that request in the audit log on the control plane node. Other reads of the same Secret are in the log too, so check the impersonated user and the response code.
3. Create the ConfigMap `denied-read-report` in `starfleet-036-050-01-02` with the keys `auditID` (the `auditID` of that record), `user` (its `user.username`), `impersonatedUser` (its `impersonatedUser.username`) and `code` (`403`).

## Constraints

Work only in this lab's namespaces `starfleet-036-050-01-02` and `outpost-036-050-01-02` and its own node containers. Do not give the `drifter` ServiceAccount any permissions. Do not change the audit policy or the API server.

## How the answer is checked

Each check gives one point: the audit log holds a `ResponseComplete` record of a denied `get` of `navigation-key` with the code 403 and the impersonated user `drifter`; the ConfigMap `denied-read-report` names the `auditID` and the `user` of such a record and the impersonated user. The grader reads the audit log and the ConfigMap live.
