---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Drop All Capabilities And Block Privilege Escalation

Run a workload as a non-root user with no Linux capabilities and no way to gain privileges. Use the isolated `starfleet-036-040-02-01` environment to verify the result.

## Objective

Run a workload as a non-root user with no Linux capabilities and no way to gain privileges.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Use the private kubeconfig for `ats-036-lab-040-02-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-02-01)"` and check that the context is `kind-astro-ats-036-lab-040-02-01`.

## Tasks

1. Create Pod `capability-free` in `starfleet-036-040-02-01` using `docker.io/library/busybox:1.37.0`, container `worker`, command `["sh", "-c", "sleep 3600"]` and restart policy `Never`. Set user and group to `2000` and require a non-root user.
2. Set seccomp profile `RuntimeDefault`, disable privilege escalation and drop `ALL` capabilities.
3. Inspect the running process. Verify UID `2000`, zero effective and bounding capabilities, `NoNewPrivs: 1` and seccomp filter mode `2`.

## Constraints

Work only in this lab’s namespaces `starfleet-036-040-02-01` and `outpost-036-040-02-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The running process has no capabilities or privilege escalation. The grader reads live resources and evidence; it does not award points for preserving the starting state.
