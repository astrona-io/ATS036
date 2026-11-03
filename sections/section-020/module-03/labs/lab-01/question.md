---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find Which Account Can Read Secrets

Find the ServiceAccount that can read Secrets and record the binding that grants the access. Use the isolated `starfleet` environment to verify the result.

## Objective

Find the ServiceAccount that can read Secrets and record the binding that grants the access.

## Starting state

The namespace `starfleet` holds Secret `db-credentials` and two ServiceAccounts, `reporter` and `auditor`. One of them can read Secrets. Pod `data-client` and the healthy probe application are separate from that evidence.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Do not change any RBAC object. Find the ServiceAccount that can `get` Secrets in `starfleet`. Create ConfigMap `access-finding` with `subject` set to its full user name (`system:serviceaccount:starfleet:<name>`), `verb: get`, `resource: secrets` and `binding` set to the name of the RoleBinding that grants the access.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
