---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Attribute An API Attempt To A Workload Identity

Classify a real denied Secret request and bind the finding to its actor and audit identifier.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-030-01-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-01-01)"` and check that the context is `kind-astro-ats-036-lab-030-01-01`.

## Tasks

1. Find the denied Secret request from `threat-reader` and inspect its audit ID, stage, authenticated identity, source addresses and bound Pod attributes.
2. Create `audit-finding` in `starfleet-036-030-01-01` with keys `actor`, `resource`, `namespace`, `code`, `finding`, `auditID`, `stage` and `requestURI`. Set `finding` to `unauthorized-secret-read` and copy the other values from the `ResponseComplete` record.
3. Add `podName`, `podUID`, `podIP` and `sourceIP` to that report. Match the name and UID to `threat-client` and the audit event’s bound Pod attributes. Record its live Pod IP separately from an address in the event’s `sourceIPs`; NAT can make these differ. Do not infer a human identity from the ServiceAccount.

## Constraints

Work only in this lab’s namespaces `starfleet-036-030-01-01` and `outpost-036-030-01-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The finding binds the request to a live Pod UID. The grader reads live resources and evidence; it does not award points for preserving the starting state.
