---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Falco Rule Against Live Processes Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-010-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-010-02-02`. Falco files and the Falco service belong to root, so the commands below use `sudo`.

## Write the rule and its exception

A Falco rule has a `condition`, an `output` and a `priority`. The condition below matches the exit event (`evt.dir = <`) of `execve` or `execveat`, so it matches only a program start that the kernel completed. `user.name` and `proc.name` limit it to shells of `probe-user`. An exception lists fields, comparison operators and values. Falco skips an event only when every field matches its value, so this exception skips `sh` with the approved command line and nothing else.

Save this as `falco-rules-local.yaml`:

```yaml
- rule: Unexpected probe shell
  desc: Shell execution by the probe account outside approved maintenance
  condition: >
    evt.type in (execve, execveat) and evt.dir = <
    and user.name = probe-user and proc.name in (sh, dash, bash)
  output: Shell started (command=%proc.cmdline user=%user.name process=%proc.name)
  priority: WARNING
  exceptions:
  - name: approved_maintenance
    fields: [proc.name, proc.cmdline]
    comps: [=, startswith]
    values:
    - [sh, "sh /opt/approved-maintenance.sh "]
```

Copy it over the custom rule file:

```sh
sudo cp falco-rules-local.yaml /etc/falco/falco_rules.local.yaml
```

## Load the rule

`falco -V` checks a rule file and exits with an error if the file is not valid. Falco reads its rules only when it starts, so restart the service after the check:

```sh
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
sudo systemctl is-active falco-modern-bpf.service
```

The last command prints `active` once Falco runs again.

## Test the positive and negative cases

Start one shell of each kind. Each command line ends with a word that names the case, so you can find it in the alerts:

```sh
sudo runuser -u probe-user -- /bin/sh -c 'sleep 0.2' unexpected-check
sudo runuser -u probe-user -- /bin/sh /opt/approved-maintenance.sh approved-check
sudo runuser -u other-user -- /bin/sh -c 'sleep 0.2' outside-check
sudo runuser -u probe-user -- /bin/bash -c 'sleep 0.2' second-check
sudo grep 'Unexpected probe shell' /var/log/falco-events.jsonl | tail -n 5
```

Each alert line is a JSON object with the fields `rule`, `priority` (`Warning`), `output` and `output_fields`. The lines for `unexpected-check` and `second-check` are there, and no line names `approved-check` or `outside-check`. The `bash` alert comes after the two negative cases, so it shows that Falco was still running when they ran. If no alert appears at all, read `sudo journalctl -u falco-modern-bpf.service` before you change the rule: a stopped sensor raises no alert, so silence alone does not prove that an exception works.
