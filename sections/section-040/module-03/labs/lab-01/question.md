---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Update A Workload By Replacement With A Read-Only Root

Replace the Pods of a Deployment through its template so that they run version v2 with a read-only root filesystem and a writable temporary path. Use the isolated `starfleet-036-040-03-01` environment to verify the result.

## Objective

Replace the Pods of a Deployment through its template so that they run version v2 with a read-only root filesystem and a writable temporary path.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The `probe` Deployment runs version `v1` with a writable root filesystem. The `shuttle` Pod can call the `probe` Service. Complete the required change without replacing unrelated resources.

Use the private kubeconfig for `ats-036-lab-040-03-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-03-01)"` and check that the context is `kind-astro-ats-036-lab-040-03-01`.

## Tasks

1. Update the `probe` Deployment in `starfleet-036-040-03-01` through its Pod template. Set its `VERSION` environment variable to `v2` and make the container root filesystem read-only.
2. Keep the `app` ConfigMap volume mounted read-only at `/app`. Add an `emptyDir` volume named `tmp` at `/tmp`; do not add host paths.
3. Wait for two ready replicas. Verify that the Service returns `version=v2`, writes to `/tmp` work and writes to `/root-file` fail because the filesystem is read-only.

## Constraints

Work only in this lab’s namespaces `starfleet-036-040-03-01` and `outpost-036-040-03-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The rollout serves v2 with a read-only root and writable temporary storage. The grader reads live resources and evidence; it does not award points for preserving the starting state.
