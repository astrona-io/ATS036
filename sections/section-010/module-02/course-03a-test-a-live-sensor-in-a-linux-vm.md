---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Live Sensor In A Linux VM

A syntactically valid rule can still match no events. A quiet sensor can mean a narrow rule, an approved exception, a stopped service or a failed driver. Prove detection with a positive case before interpreting silence.

## Runtime and scope

The independent live-sensor lab boots an Ubuntu QEMU VM with Falco's modern eBPF sensor. It observes real Linux process-execution events. The rule uses the Linux account `probe-user` as its scope. Kubernetes namespace fields need container and Kubernetes metadata enrichment; a host-account test does not prove that enrichment. The kind exercise assesses the namespace-scoped rule document separately.

Connect with `astrona ssh ats-036-lab-010-02-02` when the lab starts. All commands in this lesson run inside that disposable VM.

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

Falco validates the file before it is put into service:

```sh
sudo falco -V /etc/falco/training-rules.yaml
sudo systemctl restart training-falco
sudo journalctl -u training-falco -n 20 --no-pager
```

A parser error requires a rule repair. A driver initialization error requires a sensor repair. Wait until the syscall source is running, then generate an unexpected shell, the approved script, an out-of-scope shell and another unexpected shell:

```sh
sudo runuser -u probe-user -- /bin/sh -c 'sleep 0.2' unexpected-example
sudo runuser -u probe-user -- /bin/sh /opt/approved-maintenance.sh approved-example
sudo runuser -u other-user -- /bin/sh -c 'sleep 0.2' outside-example
sudo runuser -u probe-user -- /bin/bash -c 'sleep 0.2' second-example
sudo tail -n 20 /var/log/training-falco.jsonl
```

The two unexpected identifiers should appear in alerts; the approved and out-of-scope identifiers should not. The final positive event checks that the detector survived the negative cases. Use fresh identifiers for another run so old records cannot supply the evidence. Finite tests establish behavior for the generated cases; they do not prove that every possible attack is detected or that the sensor never drops events.
