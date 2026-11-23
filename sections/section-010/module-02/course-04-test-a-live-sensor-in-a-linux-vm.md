---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Live Sensor In A Linux VM

A syntactically valid rule can still match no events. A quiet sensor can mean a narrow rule, an approved exception, a stopped service or a failed driver. Prove detection with a positive case before interpreting silence.

## Runtime and scope

The live-sensor lab boots an Ubuntu VM (virtual machine) with a one-node kubeadm cluster and Falco 0.45.2. Falco runs as the systemd service `falco-modern-bpf.service`, which uses the modern eBPF (extended Berkeley Packet Filter) driver to read real Linux system calls. Falco loads its default rules and then the custom rule file `/etc/falco/falco_rules.local.yaml`. A file in `/etc/falco/config.d` makes it write each alert as one JSON line to `/var/log/falco-events.jsonl`.

The rule in this lesson uses the Linux account `probe-user` as its scope. Kubernetes namespace fields need container and Kubernetes metadata, and a host-account test does not prove that those fields work. Namespace-scoped rules are tested separately.

The commands in this lesson run in that lab VM. Open a shell on it with `astrona ssh astro-ats-036-lab-010-02-02` when the lab starts.

## Conditions and output

A successful `execve` or `execveat` event reports the new process. Restrict the syscall rule before selecting the account and shell:

```yaml
condition: >
  evt.type in (execve, execveat) and evt.dir = <
  and user.name = probe-user and proc.name in (sh, dash, bash)
output: Shell started (command=%proc.cmdline user=%user.name process=%proc.name)
priority: WARNING
```

The `<` direction selects syscall exit events. Failed execution can leave the old process identity in the event, so the live test uses successful shell launches and checks the emitted command. The output needs the command and account to let you distinguish your test cases in the JSON `output_fields` object.

## A bounded exception

The provided maintenance script accepts an identifier and runs only a fixed sleep. Its approved command line begins with `sh /opt/approved-maintenance.sh `, including the final space. Combine the process name with that prefix:

```yaml
exceptions:
- name: approved_maintenance
  fields: [proc.name, proc.cmdline]
  comps: [=, startswith]
  values:
  - [sh, "sh /opt/approved-maintenance.sh "]
```

This exception remains inside the account scope established by the rule. Excluding every shell for `probe-user` would also suppress the unexpected commands. A production exception also needs ownership and protection of the approved script; a writable approved script could run unwanted code under the exception.

## Validate, reload and observe

<!-- astrona:playground:renew -->

`falco -V` checks the rule file before you restart the service:

```sh
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
sudo journalctl -u falco-modern-bpf.service -n 20 --no-pager
```

A parser error requires a rule repair. A driver initialization error requires a sensor repair. Wait until the syscall source is running, then generate an unexpected shell, the approved script, an out-of-scope shell and another unexpected shell:

```sh
sudo runuser -u probe-user -- /bin/sh -c 'sleep 0.2' unexpected-example
sudo runuser -u probe-user -- /bin/sh /opt/approved-maintenance.sh approved-example
sudo runuser -u other-user -- /bin/sh -c 'sleep 0.2' outside-example
sudo runuser -u probe-user -- /bin/bash -c 'sleep 0.2' second-example
sudo grep 'Unexpected probe shell' /var/log/falco-events.jsonl | tail -n 5
```

The two unexpected identifiers should appear in alerts; the approved and out-of-scope identifiers should not. The final positive event checks that the detector survived the negative cases. Use fresh identifiers for another run so old records cannot supply the evidence. Finite tests establish behavior for the generated cases; they do not prove that every possible attack is detected or that the sensor never drops events.
