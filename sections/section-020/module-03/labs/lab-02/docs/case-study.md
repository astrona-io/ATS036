---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

The namespace `starfleet-036-020-03-02` holds two Secrets, `db-credentials` and `ledger-token`. Deployment `billing` reads the `password` key of `db-credentials` into the environment variable `DB_PASSWORD`. Pod `reports` mounts `db-credentials` as a volume at `/etc/db`. Pod `ledger` reads `ledger-token` into an environment variable. The probe application and the `shuttle` and `drifter` Pods are not part of the evidence.

Create ConfigMap `secret-exposure` with `secret: db-credentials`, `envWorkload` and `volumeWorkload` set to `<kind>/<name>` of the workloads that read it through an environment variable and through a volume. Then change Deployment `billing` so that it has no environment variable from any Secret and mounts `db-credentials` read-only at `/etc/db` with `defaultMode: 0400`. Keep `DB_HOST`, and leave Pods `reports` and `ledger` unchanged.
