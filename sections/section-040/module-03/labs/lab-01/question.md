---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Update A Workload By Replacement With A Read-Only Root

Replace the Pods of a Deployment through its template so that they run version v2 with a read-only root filesystem and a writable temporary path. Use the isolated `starfleet` environment to verify the result.

## Objective

Replace the Pods of a Deployment through its template so that they run version v2 with a read-only root filesystem and a writable temporary path.

## Starting state

The `probe` Deployment runs version `v1` with a writable root filesystem. The `shuttle` Pod can call the `probe` Service. Complete the required change without replacing unrelated resources.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Change Deployment `probe` in `starfleet` through its Pod template. Set the `VERSION` environment variable to `v2`. Set `readOnlyRootFilesystem: true` on the `probe` container. Keep the existing `app` volume and its read-only mount first, then add an `emptyDir` volume named `tmp` mounted at `/tmp`. Do not use a `hostPath` volume. The rollout must finish with two ready replicas, the service must answer with `version=v2`, writing to `/tmp` must work, and writing `/root-file` must fail.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
