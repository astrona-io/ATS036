---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Record Interactive Pod Access In The Audit Log

Run a command in a Pod through the API server and bind the audit record of that exec request to a report.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-050-02-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-02-01)"` and check that the context is `kind-astro-ats-036-lab-050-02-01`.

## Tasks

1. Inspect the staged audit policy for `pods/exec`, then run `id` in Pod `shuttle` through the Kubernetes API.
2. Find its audit event and verify that it identifies the Pod, namespace and `command=id`, uses `Metadata` level and contains no request or response body.
3. Create `audit-exec` in `starfleet-036-050-02-01` with `resource: pods`, `subresource: exec`, `podName: shuttle`, `command: id` and `level: Metadata`. Keep the policy and API available.

## Constraints

Work only in this lab’s namespaces `starfleet-036-050-02-01` and `outpost-036-050-02-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

A real exec request is audited at Metadata level. The grader reads live resources and evidence; it does not award points for preserving the starting state.
