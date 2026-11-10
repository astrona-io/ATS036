---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Trace A Connection To Its Source Pod

Identify the Pod that sends unexpected requests to the probe Service and record its address.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment runs the `probe` Deployment with two replicas and a Service in `starfleet-036-030-03-01`, and the idle Pods `shuttle` and `drifter`. One more Pod, in the `outpost-036-030-03-01` namespace, sends a request to the `probe` Service every five seconds. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-030-03-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-03-01)"` and check that the context is `kind-astro-ats-036-lab-030-03-01`.

## Tasks

1. Read probe access logs and identify the source address of the unexpected requests. Map it to Pod `intruder` in `outpost-036-030-03-01`.
2. Create `lateral-finding` in `starfleet-036-030-03-01` with keys `sourcePod`, `sourceNamespace`, `sourceIP`, `target` and `finding`. Use the live source address, `probe` as the target and `lateral-movement-to-probe` as the finding.
3. Verify that the reported IP belongs to the source Pod and occurs in probe access logs. Keep both workloads running.

## Constraints

Work only in this lab’s namespaces `starfleet-036-030-03-01` and `outpost-036-030-03-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The report connects a live source Pod to probe access logs. The grader reads live resources and evidence; it does not award points for preserving the starting state.
