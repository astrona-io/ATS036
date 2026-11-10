---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Verify Metadata Audit Records Exclude Secret Payloads

Generate a real Secret read record and verify useful metadata without credential bodies.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-050-01-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-01)"` and check that the context is `kind-astro-ats-036-lab-050-01-01`.

## Tasks

1. Inspect the staged audit policy and read the disposable `audit-token` Secret through the API. Find the corresponding `ResponseComplete` event.
2. Verify that its audit level is `Metadata` and neither the request nor response body is logged.
3. Create `audit-review` in `starfleet-036-050-01-01` with `level: Metadata`, `resource: secrets` and `result: payload-excluded`. Preserve the staged policy and API availability.

## Constraints

Work only in this lab’s namespaces `starfleet-036-050-01-01` and `outpost-036-050-01-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

Secret reads are audited without their payloads. The grader reads live resources and evidence; it does not award points for preserving the starting state.
