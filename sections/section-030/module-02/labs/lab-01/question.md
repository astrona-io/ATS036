---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Contain A Persistent Workload And Its Binding

Find the controller and binding behind an unexpected Pod, record them and contain both.

Solve this question on: `terminal`

Allow 10–15 minutes for task work.

## Starting state

The isolated environment runs the `cache-sync` Deployment with one replica, which uses the `build-helper` ServiceAccount, and two RoleBindings in the `starfleet-036-030-02-01` namespace. The `cache-sync` Deployment is not part of the application. The required result has not been configured.

Use the private kubeconfig for `ats-036-lab-030-02-01`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-01)"` and check that the context is `kind-astro-ats-036-lab-030-02-01`.

## Tasks

1. Inspect Deployment `cache-sync`, its ServiceAccount and RoleBinding. Create `persistence-finding` in `starfleet-036-030-02-01` with keys `deployment`, `serviceAccount`, `binding`, `clusterRole` and `finding`. Record the observed names and `persistence-and-escalated-authority`.
2. Scale `cache-sync` to zero replicas and wait until its Pods are gone. Keep the Deployment as evidence.
3. Delete RoleBinding `build-helper-edit`. Preserve the `probe-reader-view` binding and the probe workload.

## Constraints

Work only in this lab’s namespaces `starfleet-036-030-02-01` and `outpost-036-030-02-01` and its own node containers. Preserve unrelated resources and the staged evidence. Cluster startup and API restarts add time to the task estimate.

## How the answer is checked

The report preserves the persistence and authority relationships. The grader reads live resources and evidence; it does not award points for preserving the starting state.
