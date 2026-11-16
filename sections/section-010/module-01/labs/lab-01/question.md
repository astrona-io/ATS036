---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Detect A Denied API Access Attempt

Classify a real denied Secret request and bind the finding to its actor and audit identifier.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-010-01-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-01-01)"` and check that the context is `kind-astro-ats-036-lab-010-01-01`.

## Tasks

1. Find the `ResponseComplete` audit event for the `threat-reader` ServiceAccount attempting to read the `audit-token` Secret. Identify its actor, resource, namespace and response code.
2. Create `audit-finding` in `starfleet-036-010-01-01` with keys `actor`, `resource`, `namespace`, `code`, `finding`, `auditID`, `stage` and `requestURI`. Use `unauthorized-secret-read` for `finding` and copy the other values from that event.
3. Verify that the record reports code `403` and contains no `requestObject` or `responseObject`. Keep Secret bodies out of the report.

## Constraints

Work only in this lab’s namespaces `starfleet-036-010-01-01` and `outpost-036-010-01-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The finding matches a real denied Secret request. The grader reads live resources and evidence; it does not award points for preserving the starting state.
