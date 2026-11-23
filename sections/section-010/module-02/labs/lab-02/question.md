---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Falco Rule Against Live Processes

Allow about 15 minutes for the tasks.

The account `probe-user` on the lab node runs one approved maintenance script. Any other shell that this account starts must raise a Falco alert, while the maintenance script and other accounts stay quiet.

Solve this question on: `terminal`

## Starting state

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. Falco 0.45.2 is installed on the node. Falco is a runtime security tool: it reads system calls from the Linux kernel and raises an alert when an event matches a rule. The systemd service `falco-modern-bpf.service` runs Falco with its modern eBPF (extended Berkeley Packet Filter) driver, the kernel program that sends the system call events to Falco.

Falco loads its own rules and then the custom rule file `/etc/falco/falco_rules.local.yaml`. That file holds the rule `Unfinished training rule`, which matches no process of this task. The file `/etc/falco/config.d/training-output.yaml` makes Falco write each alert as one JSON line to `/var/log/falco-events.jsonl`. The accounts `probe-user` and `other-user` exist, and `/opt/approved-maintenance.sh` runs `sleep 0.2`.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-010-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-010-02-02`. You are logged in as the `student` user. Falco files and the service belong to root, so run those commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. In `/etc/falco/falco_rules.local.yaml`, replace the unfinished rule with a rule named `Unexpected probe shell` with priority `WARNING`. It must match a successful program start (the exit event of `execve` or `execveat`) of `sh`, `dash` or `bash` by the account `probe-user`. Its output must contain `%proc.cmdline` and `%user.name`.
2. Add an exception to the rule that skips only an `sh` process whose command line starts with `sh /opt/approved-maintenance.sh ` (with the space at the end). Other shells of `probe-user` must still raise an alert. Shells of `other-user` must raise no alert.
3. Check the file with `falco -V`, then restart `falco-modern-bpf.service`. The service must keep running with the same output file.

## Constraints

Change only `/etc/falco/falco_rules.local.yaml`. Keep `falco-modern-bpf.service` running and keep the accounts, the maintenance script and the file output in `/etc/falco/config.d/training-output.yaml`. Do not write alert lines to the output file by hand, and do not exclude every shell of `probe-user`.

## How the answer is checked

Each check gives one point: new `sh` and `bash` shells of `probe-user` raise `Unexpected probe shell` alerts with priority `WARNING`, the command line and the account; the approved maintenance command and the shells of `other-user` raise no alert while a later `probe-user` shell still does. Both checks also need the cluster to stay ready.

Start one shell of each kind and read the newest lines of the output file:

```sh
sudo runuser -u probe-user -- /bin/sh -c 'sleep 0.2' unexpected-check
sudo runuser -u probe-user -- /bin/sh /opt/approved-maintenance.sh approved-check
sudo runuser -u other-user -- /bin/sh -c 'sleep 0.2' outside-check
sudo runuser -u probe-user -- /bin/bash -c 'sleep 0.2' second-check
sudo tail -n 20 /var/log/falco-events.jsonl
```

Alerts of `Unexpected probe shell` appear for `unexpected-check` and `second-check` only. The grader runs the same four shells with a new random marker and reads only the alerts that Falco writes after them.
