---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Exceptions, Testing And Limits Of A Rule

A shell rule that fires on every approved maintenance session trains people to ignore it. The answer is not to delete the rule. The answer is a narrow exception for the approved behavior. This part shows how to write an exception, how to test a rule before relying on it and which kinds of attack a process rule cannot see.

## Write a narrow exception

A Falco rule can have an `exceptions` block. Each exception has a `name`, a list of `fields` that it compares, a list of comparison operators in `comps` and a list of `values` to match. An event that matches an exception does not produce an alert.

For example, an approved start-up script runs `sh` once as a child of the `python` process of the `probe` workload, and the namespace and the container name identify it:

```yaml
exceptions:
  - name: approved_startup_shell
    fields: [k8s.ns.name, container.name, proc.pname, proc.cmdline]
    comps: [=, =, =, =]
    values:
      - [starfleet, probe, python, "sh /app/startup.sh"]
```

The exception names four fields at once. A shell that has a different command line or a different parent still produces an alert. A broad exception such as "ignore every shell in `starfleet`" would turn the rule off for the whole namespace.

Record who approved each exception and why, and review the list on a schedule. An exception that nobody owns becomes a hole.

## Test before you trust

A rule that has never fired has not been shown to work. Test it in three steps.

First, check the syntax. Falco can validate a rules file with its `-V` option before the file is deployed. A typo in a field name makes the rule file invalid, which is better than a rule that silently never matches.

Second, produce the behavior in a test environment. Start a shell in a test Pod of the `starfleet` namespace and check that the alert appears with the expected pod and command line. Do this on a Pod that is not production.

Third, produce the normal behavior and check that it stays quiet. Start-up of the workload and the approved script must not produce an alert.

## What a process rule cannot see

A rule for process creation answers one question: did a shell start. Several attacks do not start a shell. An attacker who has code execution inside the Python interpreter can read files, open connections and call the Kubernetes API without a new process. A rule for file reads, for network connections or an audit rule for API calls is a separate detection.

A rule also depends on its sensor. If the sensor Pod is not running on a node, nothing on that node is detected, and no alert looks the same as nothing happened. Monitor that the sensor itself is running on every node.

The reader now knows how to write, narrow and test a rule, and the limits of what one rule covers. The module summary collects these points.

## Common pitfalls

> [!WARNING]
> - **Writing an exception on one field.** One field is almost always too broad. Combine namespace, container, parent and command line.
> - **Disabling a noisy rule.** A disabled rule detects nothing. Tune it with an exception instead.
> - **Testing only the alert.** Also test that the approved behavior stays quiet, or the rule will be disabled later.
> - **Assuming one rule covers an attack.** A shell rule does not detect a file read or an API call.
