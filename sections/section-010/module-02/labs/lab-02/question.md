---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Falco Rule Against Live Processes

Solve this question on: `terminal`

This independent QEMU VM runs Falco 0.45.2 with its modern eBPF sensor. The `training-falco` service loads `/etc/falco/training-rules.yaml` and writes JSON alerts to `/var/log/training-falco.jsonl`. Its initial rule never matches the exercise processes. The accounts `probe-user` and `other-user` exist, and `/opt/approved-maintenance.sh` runs a harmless fixed command.

```sh
astrona ssh ats-036-lab-010-02-02
```

Run the following tasks inside that VM. No Kubernetes cluster is needed for this host-process exercise.

Allow 10–15 minutes for task work. First boot, image download and package installation add time.

## Tasks

1. Replace the unfinished rule with `Unexpected probe shell`, priority `WARNING`. Match successful process-execution events for shells (`sh`, `dash`, `bash`) belonging to `probe-user`. Include `%proc.cmdline` and `%user.name` in the alert output.
2. Exclude only the approved command shape `sh /opt/approved-maintenance.sh ` followed by its test identifier. Keep other shells by that account detectable and exclude activity by other accounts through the rule scope.
3. Validate the rule with Falco, restart `training-falco`, and generate unexpected shells, approved maintenance and an out-of-scope shell. Inspect real JSON alerts and confirm both positive and negative cases.

## Constraints

- Keep the real eBPF sensor running; preserve the service unit, output path, accounts and maintenance script.
- Change only `/etc/falco/training-rules.yaml`. Do not manufacture alert records.
- Keep both `sh` and `bash` detection active. A rule that excludes all activity by `probe-user` is too broad an exception.

## How the answer is checked

The grader generates new commands with random identifiers and reads only subsequent sensor output. Unexpected `sh` and `bash` executions must produce alerts with the right rule, priority and account; approved maintenance and the other account must produce none. A positive event after the negative cases checks that the sensor stayed active. This proves host-process rule behavior, not Kubernetes metadata enrichment.
