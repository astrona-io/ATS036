---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Scope Live Falco Events With Kubernetes Metadata

Allow about 15 minutes for the tasks.

A shell in the `reporter` Pod of `starfleet-036-010-02-03` must raise a Falco alert that names the namespace, the Pod and the Pod UID. The same Pod in `outpost-036-010-02-03` and the approved commands must stay quiet.

Solve this question on: `terminal`

## Starting state

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. Falco 0.45.2 runs on the node as the systemd service `falco-modern-bpf.service`. Falco is a runtime security tool: it reads system calls from the Linux kernel and raises an alert when an event matches a rule. Its container plugin adds the container and Kubernetes fields to each event, such as `k8s.ns.name` (the namespace), `k8s.pod.name` and `k8s.pod.uid`.

The namespaces `starfleet-036-010-02-03` and `outpost-036-010-02-03` each run a Pod named `reporter`. The custom rule file `/etc/falco/falco_rules.local.yaml` holds the rule `Training namespace shell`. It selects the namespace `unfinished`, which does not exist, and its output shows only the command line. Falco writes each alert as one JSON line to `/var/log/falco-events.jsonl`.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-010-02-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-010-02-03`. You are logged in as the `student` user. Falco files and the service belong to root, so run those commands with `sudo`.

## Tasks

1. Fix the rule `Training namespace shell` in `/etc/falco/falco_rules.local.yaml`. Keep its name and its priority `WARNING`. It must match a successful start of `sh` or `bash` in the namespace `starfleet-036-010-02-03`, except a command line that contains `approved-`.
2. The rule output must show the command line, the namespace, the Pod name and the Pod UID.
3. Check the file with `falco -V`, then restart `falco-modern-bpf.service`. Do not delete or change the Pods or the namespaces.

## Constraints

Change only `/etc/falco/falco_rules.local.yaml`. Keep `falco-modern-bpf.service` running and keep the file output in `/etc/falco/config.d/training-output.yaml`. Work only in the namespaces `starfleet-036-010-02-03` and `outpost-036-010-02-03`, and do not write alert lines to the output file by hand.

## How the answer is checked

Each check gives one point: new shells in the `reporter` Pod of `starfleet-036-010-02-03` raise `Training namespace shell` alerts with the namespace, the Pod name and the Pod UID; the approved command and a shell in `outpost-036-010-02-03` raise no alert while a later shell in the monitored Pod still does.

Run a shell in each Pod and read the newest alerts of the rule:

```sh
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' unexpected-check
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' approved-check
kubectl -n outpost-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' outside-check
sudo grep 'Training namespace shell' /var/log/falco-events.jsonl | tail -n 5
```

Only `unexpected-check` raises an alert. The grader runs the same shells with a new random marker, plus one more shell in the monitored Pod at the end, and compares the Pod UID in the alert with the live Pod.
