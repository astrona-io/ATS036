---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Report A Risky Pod Specification

Record the risky settings of a Pod from its specification. Use the isolated `starfleet-036-020-02-01` environment to verify the result.

## Objective

Record the risky settings of a Pod from its specification.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

Pod `suspect-pod` runs a container with extra privileges and mounts a directory of the node. Pod `login-service` and the healthy probe application are separate from that evidence Pod.

Use the private kubeconfig for `ats-036-lab-020-02-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-02-01)"` and check that the context is `kind-astro-ats-036-lab-020-02-01`.

## Tasks

1. Inspect Pod `suspect-pod` in `starfleet-036-020-02-01`. Identify its privileged setting and the host path mounted into it.
2. Create `pod-risk-report` in `starfleet-036-020-02-01` with keys `pod`, `privileged` and `hostPath`, using the observed Pod name and field values.
3. Verify the report against the live Pod. Preserve that Pod and its configuration for the investigation.

## Constraints

Work only in this lab’s namespaces `starfleet-036-020-02-01` and `outpost-036-020-02-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The report matches the preserved risky Pod. The grader reads live resources and evidence; it does not award points for preserving the starting state.
