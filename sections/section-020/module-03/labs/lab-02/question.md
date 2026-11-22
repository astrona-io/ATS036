---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Move A Secret From An Environment Variable To A Read-Only Volume

Allow about 10 minutes for the tasks.

A crash report from the station's billing service printed its whole environment, database password included, and the security officer wants that path closed. Find which workloads read the database Secret and how, then move the billing service from an environment variable to a read-only file. Use the isolated `starfleet-036-020-03-02` environment.

## Objective

Find how workloads read a Secret, and replace an environment variable with a read-only secret volume.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-020-03-02` holds Secrets `db-credentials` and `ledger-token`, Deployment `billing` and Pods `reports` and `ledger`. The probe application and the `shuttle` and `drifter` Pods are not part of the evidence.

Use the private kubeconfig for `ats-036-lab-020-03-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-03-02)"` and check that the context is `kind-astro-ats-036-lab-020-03-02`.

## Tasks

1. Find the workload in `starfleet-036-020-03-02` that reads Secret `db-credentials` through an environment variable, and the workload that mounts it as a volume.
2. Create ConfigMap `secret-exposure` in `starfleet-036-020-03-02` with the keys `secret` (set to `db-credentials`), `envWorkload` and `volumeWorkload`. Write each workload as `<kind>/<name>` in lowercase, for example `deployment/web` or `pod/web`.
3. Change Deployment `billing` so that no container reads any Secret through `env` or `envFrom`. Mount Secret `db-credentials` as a secret volume read-only at `/etc/db` with `defaultMode: 0400`. Keep the environment variable `DB_HOST`.
4. Wait for the rollout to finish. Check that the container can read `/etc/db/password` and no longer has `DB_PASSWORD` in its environment.

## Constraints

Work only in this lab’s namespaces `starfleet-036-020-03-02` and `outpost-036-020-03-02`. Do not change or delete the Secrets, Pod `reports` or Pod `ledger`. Do not print the Secret value into a ConfigMap or a log. Cluster startup adds time to the task estimate.

## How the answer is checked

Each check gives one point: the report names the workloads that read Secret `db-credentials` through an environment variable and through a volume; Deployment `billing` reads `db-credentials` only from a read-only secret volume with mode 0400 at `/etc/db`, its rollout is complete, the running container can read the file and has no `DB_PASSWORD` variable. The grader reads the live resources and runs bounded `kubectl exec` requests in the running container.
