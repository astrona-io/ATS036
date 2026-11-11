---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find Which Account Can Read Secrets

Find the ServiceAccount that can read Secrets and record the binding that grants the access. Use the isolated `starfleet-036-020-03-01` environment to verify the result.

## Objective

Find the ServiceAccount that can read Secrets and record the binding that grants the access.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The namespace `starfleet-036-020-03-01` holds Secret `db-credentials` and two ServiceAccounts, `reporter` and `auditor`. One of them can read Secrets. Pod `data-client` and the healthy probe application are separate from that evidence.

Use the private kubeconfig for `ats-036-lab-020-03-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-03-01)"` and check that the context is `kind-astro-ats-036-lab-020-03-01`.

## Tasks

1. Test whether ServiceAccounts `reporter` and `auditor` can get Secrets in `starfleet-036-020-03-01`. Identify the RoleBinding and Role granting the reporter access.
2. Create `access-finding` in `starfleet-036-020-03-01` with keys `subject`, `verb`, `resource` and `binding`. Record the full ServiceAccount identity, `get`, `secrets` and the binding name.
3. Verify that the named binding belongs to the reported subject. Keep the reporter permission and the auditor denial unchanged.

## Constraints

Work only in this lab’s namespaces `starfleet-036-020-03-01` and `outpost-036-020-03-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The report identifies the binding that grants Secret access. The grader reads live resources and evidence; it does not award points for preserving the starting state.
