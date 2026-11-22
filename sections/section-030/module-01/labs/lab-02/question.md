---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Isolate A Compromised Pod And Revoke Its Token

Allow about 10 minutes for the tasks.

The `threat-client` Pod in `starfleet-036-030-01-02` has read Secrets it should never see. Contain it now, but keep it running: the incident team still needs the Pod as evidence.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-030-01-02` runs the bare Pod `threat-client` as the ServiceAccount `threat-reader`, and the Deployment `probe` as the ServiceAccount `probe-reader`. Each ServiceAccount has its own RoleBinding to the Role `secret-reader`, which allows `get` and `list` on Secrets. A long-lived token Secret exists for `threat-reader`. The ConfigMap `incident-ticket` records the UID of the `threat-client` Pod under investigation.

Use the private kubeconfig for `ats-036-lab-030-01-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-01-02)"` and check that the context is `kind-astro-ats-036-lab-030-01-02`.

## Tasks

1. Check that the UID of `threat-client` matches `podUID` in `incident-ticket`. Then add the label `incident=quarantine` to `threat-client`. Do not delete, restart or recreate the Pod.
2. Create the NetworkPolicy `quarantine` in `starfleet-036-030-01-02`. It selects only Pods with the label `incident=quarantine` and denies all their ingress and egress traffic.
3. Delete every Secret of the type `kubernetes.io/service-account-token` that holds a token for `threat-reader`.
4. Remove the RoleBinding that gives `threat-reader` access to Secrets, so that `threat-reader` can no longer `get` or `list` Secrets. `probe-reader` must keep its access, so keep the Role `secret-reader` and the binding of `probe-reader`.

## Constraints

Work only in the namespace `starfleet-036-030-01-02`. Do not change the Deployment `probe`, the ConfigMap `incident-ticket` or the Role `secret-reader`. Cluster startup adds time to the task estimate.

## How the answer is checked

Each check gives one point: the original `threat-client` Pod (same UID) carries `incident=quarantine` and still runs; the NetworkPolicy `quarantine` selects `incident=quarantine` and denies all ingress and egress; no token Secret for `threat-reader` remains; `threat-reader` can no longer get or list Secrets while `probe-reader` still can. The grader reads live resources and asks the API server with `kubectl auth can-i`.
