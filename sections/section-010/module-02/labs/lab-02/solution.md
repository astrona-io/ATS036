---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Solution

Inside the VM, write `/etc/falco/training-rules.yaml` with `sudo tee`:

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

Validate the file before restarting the service:

```sh
sudo falco -V /etc/falco/training-rules.yaml
sudo systemctl restart training-falco
sudo systemctl status training-falco --no-pager
```

Wait until Falco has loaded its syscall source, then generate the test cases:

```sh
sudo runuser -u probe-user -- /bin/sh -c 'sleep 0.2' unexpected-example
sudo runuser -u probe-user -- /bin/sh /opt/approved-maintenance.sh approved-example
sudo runuser -u other-user -- /bin/sh -c 'sleep 0.2' outside-example
sudo runuser -u probe-user -- /bin/bash -c 'sleep 0.2' second-example
sudo tail -n 20 /var/log/training-falco.jsonl
```

Look for alerts containing `unexpected-example` and `second-example`, and no alerts containing the two negative identifiers. If nothing appears, inspect `journalctl -u training-falco` before changing the rule. A stopped sensor cannot prove an exception works. Submit from the host with `astrona submit ats-036-lab-010-02-02`; the grader repeats the experiment with new identifiers.
