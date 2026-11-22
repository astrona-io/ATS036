---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Find And Limit A Workload That Can Exhaust Its Node

Allow about 10 minutes for the tasks.

The node that runs `starfleet-036-030-03-02` is short of memory. One container keeps getting killed, and one workload can take as much CPU and memory as it wants. Find both and set limits so that no container in the namespace runs without them.

## Objective

Find the workload without resource limits and the Pod whose container was killed for using too much memory, then add limits to the workload and default limits to the namespace.

Solve this question on: `terminal`

## Starting state

The namespace runs the `probe` Deployment, the `cruncher` Deployment and the Pods `shuttle` and `memory-hog`. Every container has resource limits except one. One container has already been killed and restarted. The namespace has no LimitRange.

Use the private kubeconfig for `ats-036-lab-030-03-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-03-02)"` and check that the context is `kind-astro-ats-036-lab-030-03-02`.

## Tasks

1. List the CPU and memory limits and the last termination reason of every container in `starfleet-036-030-03-02`.
2. Create the ConfigMap `impact-report` in `starfleet-036-030-03-02` with two keys: `unlimitedWorkload`, the name of the Deployment whose container has no limits at all, and `oomKilledPod`, the name of the Pod whose container was last terminated with the reason `OOMKilled`.
3. Give the container `worker` of the `cruncher` Deployment the requests `cpu: 10m` and `memory: 16Mi` and the limits `cpu: 200m` and `memory: 64Mi`, and wait until the new Pod runs.
4. Create a LimitRange named `container-limits` in `starfleet-036-030-03-02` that gives every new container a default limit of `cpu: 250m` and `memory: 128Mi` and a default request of `cpu: 10m` and `memory: 16Mi`.

## Constraints

Work only in the namespaces `starfleet-036-030-03-02` and `outpost-036-030-03-02`. Do not delete or change the `memory-hog` Pod: its status is the evidence. Do not change the command of the `cruncher` container.

## How the answer is checked

Each check gives one point: the report names the Deployment without resource limits and the Pod whose container was OOMKilled; the `cruncher` Deployment runs with CPU and memory requests and limits; a LimitRange gives a new container in the namespace default CPU and memory limits (the grader creates a test Pod with a server-side dry run, which stores nothing).
