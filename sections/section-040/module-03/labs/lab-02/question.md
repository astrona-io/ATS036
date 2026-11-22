---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Mount A hostPath Volume Read-Only

Allow about 8 minutes for the tasks.

One of the workloads in `starfleet-036-040-03-02` can write files straight into a directory of the node. Find it, record what you found and make the mount read-only, so that the workload can still read its settings but cannot change the node.

## Objective

Find the container that has a writable `hostPath` volume mount, record the finding and change the Deployment through its Pod template so that the mount is read-only.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-040-03-02` has three Deployments: `collector`, `relay` and `beacon`. Two of them mount the node directory `/var/lib/training-036-040-03-02` as a `hostPath` volume. The file `approved.txt` in that directory holds the settings that the workloads read. Only one of the two mounts lets the container write.

Use the private kubeconfig for `ats-036-lab-040-03-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-03-02)"` and check that the context is `kind-astro-ats-036-lab-040-03-02`.

## Tasks

1. Find the Deployment in `starfleet-036-040-03-02` whose container can write to a `hostPath` volume.
2. Create the ConfigMap `hostpath-finding` in `starfleet-036-040-03-02` with three keys: `workload` (the Deployment name), `volume` (the name of the volume) and `path` (the node path of the `hostPath`).
3. Change that Deployment through its Pod template so that the container mounts the volume read-only. Keep the volume, its node path and the mount path `/host-data`.
4. Wait for the rollout. Check that the new Pod still reads `/host-data/approved.txt` and that a write to `/host-data` fails with `Read-only file system`.

## Constraints

Work only in this lab's namespaces `starfleet-036-040-03-02` and `outpost-036-040-03-02`. Do not change `relay` or `beacon`, and do not delete or change `approved.txt`. Do not remove the `hostPath` volume: the workload still needs to read the file.

## How the answer is checked

Each check gives one point: the ConfigMap `hostpath-finding` names the Deployment, the volume and the node path of the writable mount; the Deployment keeps its `hostPath` volume, mounts it read-only and has finished its rollout; every Pod of the Deployment still reads `approved.txt`, a write to `/host-data` fails with `Read-only file system`, and no file from that write appears in the directory on the node. The grader reads live resources and runs its own read and write in the Pod; it does not award points for the starting state.
