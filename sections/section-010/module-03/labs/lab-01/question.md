---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Find The Audit Record Of A Pod Exec

Find the audit record of an interactive command run in a probe Pod and bind the finding to the identity and audit identifier.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet-036-010-03-01 namespace. Setup has already run one `kubectl exec` into a probe Pod. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-010-03-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-03-01)"` and check that the context is `kind-astro-ats-036-lab-010-03-01`.

## Tasks

1. Find a logged exec request to a `probe-` Pod. Identify the actor, Pod name, audit ID and a `ResponseStarted` or `ResponseComplete` stage.
2. Create `exec-finding` in `starfleet-036-010-03-01` with keys `actor`, `verb`, `resource`, `subresource`, `namespace`, `podName`, `finding`, `auditID`, `stage` and `requestURI`. Set `finding` to `unexpected-exec`; copy the request fields from that record.
3. Verify that the event represents `create` on `pods/exec`, includes the command in its URI, and excludes request and response bodies.

## Constraints

Work only in this lab’s namespaces `starfleet-036-010-03-01` and `outpost-036-010-03-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The finding identifies the actual Pod exec request. The grader reads live resources and evidence; it does not award points for preserving the starting state.
