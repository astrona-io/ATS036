---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Write A Scoped Shell Detection Rule

Write a runtime detection rule that reports shells started in the starfleet-036-010-02-01 namespace.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. No detection rule has been stored yet. The environment does not run Falco, so the rule is stored as text in a ConfigMap and checked for its fields.

Use the private kubeconfig for `ats-036-lab-010-02-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-02-01)"` and check that the context is `kind-astro-ats-036-lab-010-02-01`.

## Tasks

1. Create ConfigMap `shell-in-probe-rule` in `starfleet-036-010-02-01` with a `rules.yaml` key containing one rule and a description.
2. Set its condition to match `spawned_process` and `container`, namespace `starfleet-036-010-02-01`, and process names `sh`, `bash` and `ash`.
3. Set priority `WARNING`. Include `%k8s.pod.name` and `%proc.cmdline` in the output, then check that the probe Deployment remains healthy.

## Constraints

Work only in this lab’s namespaces `starfleet-036-010-02-01` and `outpost-036-010-02-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The grader checks the stored rule fields and probe availability. Falco is not installed, so passing does not prove that the rule loads or detects a real syscall.
