---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Run With A Restricted Security Context

Keep a non-root workload functional with a read-only root filesystem and a writable scratch volume. Use the isolated `starfleet-036-040-01-01` environment to verify the result.

## Objective

Keep a non-root workload functional with a read-only root filesystem and a writable scratch volume.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Use the private kubeconfig for `ats-036-lab-040-01-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-01-01)"` and check that the context is `kind-astro-ats-036-lab-040-01-01`.

## Tasks

1. Create Pod `restricted-reader` in `starfleet-036-040-01-01` using `docker.io/library/busybox:1.37.0`, container `reader`, command `["sh", "-c", "sleep 3600"]` and restart policy `Never`. Set user, group and filesystem group to `1000`, `runAsNonRoot: true` and seccomp profile `RuntimeDefault`.
2. Disable privilege escalation, drop `ALL` capabilities and make the root filesystem read-only. Mount an `emptyDir` volume named `scratch` at `/scratch`.
3. Wait for readiness. Verify UID `1000`, a successful write in `/scratch` and a rejected write to `/root-file` because the filesystem is read-only.

## Constraints

Disable automatic ServiceAccount token mounting on `restricted-reader`; it needs no API credentials.

Work only in this lab’s namespaces `starfleet-036-040-01-01` and `outpost-036-040-01-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The non-root Pod writes only to its scratch volume. The grader reads live resources and evidence; it does not award points for preserving the starting state.
