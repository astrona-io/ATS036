---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find A Pod's Log Files On Its Node

Allow about 8 minutes for the tasks.

The `crash-report` Pod of the `starfleet-036-020-01-02` fleet crashed once, and the log collector did not ship its logs. Find the log files on the node itself, before the kubelet removes them, and record where they are and what the crashed instance wrote.

Solve this question on: `terminal`

## Starting state

The cluster has one control-plane node and one worker. Pod `crash-report` in `starfleet-036-020-01-02` has one container, `report`. Its first instance printed `application-started` and a line `crash-token=<value>`, then exited with status 12. The kubelet started a second instance, which keeps running. A second Pod named `crash-report` runs in `outpost-036-020-01-02`.

Use the private kubeconfig for `ats-036-lab-020-01-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-01-02)"` and check that the context is `kind-astro-ats-036-lab-020-01-02`. The node containers are `astro-ats-036-lab-020-01-02-control-plane` and `astro-ats-036-lab-020-01-02-worker`; each has the same name as its node.

## Tasks

1. Find the node that runs Pod `crash-report` in `starfleet-036-020-01-02` and the UID of that Pod.
2. On that node, find the Pod's log directory under `/var/log/pods` and list the log files of container `report`.
3. Read the log file of the previous (crashed) instance on the node and find the value after `crash-token=`.
4. Create ConfigMap `node-log-evidence` in `starfleet-036-020-01-02` with the keys `nodeName`, `podUID`, `logDirectory` (the full path of the Pod's directory, without the container name), `logFiles` (the file names in the `report` directory, separated by commas, for example `0.log,1.log`) and `crashToken` (the value only).

## Constraints

Work only in this lab's namespaces `starfleet-036-020-01-02` and `outpost-036-020-01-02` and its own node containers. Do not delete, restart or change either `crash-report` Pod: deleting a Pod removes its log files from the node. Do not change or delete files on the node.

## How the answer is checked

Each check gives one point: the evidence names the node, the Pod UID and the Pod's log directory on that node; the evidence lists the log files of container `report` and the token from the previous instance's file. The grader compares the ConfigMap with the live Pod and with the files on the node that runs it.
