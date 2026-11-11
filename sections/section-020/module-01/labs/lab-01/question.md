---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Diagnose A Previous Container Exit

Select the previous container log and record the corresponding exit evidence. Use the isolated `starfleet-036-020-01-01` environment to verify the result.

## Objective

Select the previous container log and record the corresponding exit evidence.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

Pod `crash-report` prints a start marker, exits once with a nonzero status and then stays running after its restart. An emptyDir marker prevents further crashes so the previous logs remain available. The healthy probe application is separate from that evidence Pod.

Use the private kubeconfig for `ats-036-lab-020-01-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-01-01)"` and check that the context is `kind-astro-ats-036-lab-020-01-01`.

## Tasks

1. Inspect the previous `report` container instance in Pod `crash-report`, including its termination status and previous logs.
2. Create `crash-diagnosis` in `starfleet-036-020-01-01` with keys `container`, `exitCode` and `logMarker`. Record the container name, actual previous exit code and the `application-started` log marker.
3. Compare the report with the live restart count and previous logs. Leave the restarted process in place so the evidence can still be inspected.

## Constraints

Work only in this lab’s namespaces `starfleet-036-020-01-01` and `outpost-036-020-01-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The diagnosis matches the previous container instance. The grader reads live resources and evidence; it does not award points for preserving the starting state.
