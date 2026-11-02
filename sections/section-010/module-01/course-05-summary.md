---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Summary

Behavioral detection compares what a running workload does with what it is expected to do. The expected behavior comes from the Pod specification and the purpose of the application: its main process, its port, its files, its destinations and its Kubernetes identity. Behavior learned only by observation can contain the attacker's actions, so observation corrects a baseline but does not define it.

Containers share the kernel of their node, so a sensor on the node sees the system calls of every container. Falco reads these events from a kernel driver, adds container and Pod metadata, and tests them against rules with a name, a condition, an output and a priority. Tracee and Sysdig use the same data source. A rule match is an alert about an event that already happened. It does not prevent anything, and a missing alert can mean missing coverage.

The Kubernetes API server records API requests in the audit log. An event with the level `Metadata` names the authenticated user, the verb, the resource, the object, the stage, the `auditID` and the response code, without the request or response body. A `403` in a `ResponseComplete` event proves a denial, not a successful read, and it names the identity that sent the request, not the person behind it.

Triage identifies the workload and the identity, checks the baseline and looks at the events before and after. Tuning narrows a rule with an exception or an appended condition so that it stays active. Response keeps evidence first: capture the Pod object and logs, add an ephemeral container if needed, and quarantine the Pod by changing its selecting label rather than deleting it. The key facts to remember are these:

- A baseline starts from the specification and the application purpose.
- A rule match is a hypothesis, not proof, and not prevention.
- A `403` audit event shows a denied request and the identity that sent it.
- Capture evidence before you delete a suspicious Pod.

<!-- astrona:playground:destroy -->
