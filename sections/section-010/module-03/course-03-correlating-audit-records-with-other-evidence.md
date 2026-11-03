---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Correlating Audit Records With Other Evidence

One audit record answers who asked for a session in which Pod and when. It does not answer what the session did. To judge whether an `exec` request is an attack, you connect the record with other sources: the workload baseline, the Pod, the node and any runtime alert. This part shows how to do that connection and where the connection fails.

## Link by time, Pod and node

Three values connect evidence from different sources.

The first is the **time**. Every audit event has `requestReceivedTimestamp` and `stageTimestamp`. A runtime alert has its own time. Events from the same session fall in the same short window, and the clocks of the control plane and the node can differ by a small amount, so use a window of seconds, not one exact second.

The second is the **Pod**. The audit record has the Pod name in `objectRef.name`. Find where it runs:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-010-03)"
kubectl -n starfleet get pods -l app=probe -o wide
```

The `NODE` column names the node that runs each Pod. A runtime sensor on that node is the one that can show the processes of the session.

The third is the **container**. A runtime alert names a container ID, and the Pod object lists it in `status.containerStatuses`. Read the ID of the first container:

```sh
kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].containerID}{"\n"}'
```

The ID starts with the runtime name followed by `://`. A runtime alert that holds this container ID and a time inside the window belongs to the same session as the audit record.

## Compare with the baseline

The baseline of the `probe` workload says that nobody starts a shell in it. An `exec` request therefore needs an explanation. Check three things:

- Is there an approved change or an on-call ticket for that Pod at that time?
- Is the identity one that is allowed to debug this namespace?
- Does the `requestURI` show a command that fits debugging, such as `id` or `cat`, or one that fits an attack, such as a download followed by an execution?

If the answer to the first two is no, the record is a finding. If the answers are unclear, treat the Pod as suspicious and preserve evidence before anything is restarted.

## What the record cannot prove

An `exec` record proves that a request was made and which identity made it. It does not prove that the command succeeded, what it printed or which files it changed. The audit log also does not show activity that never went through the API server, such as a process that an attacker started through a vulnerability in the application. Each source covers a different part of an attack, so a missing record in one source is not proof that nothing happened.

Audit records can be deleted or never written. An attacker with access to the control plane node can change the audit file, and a policy that does not list a resource records nothing for it. Ship the audit log to a store that the cluster cannot change, and check the policy against the behaviors you want to detect.

The reader now has the three steps of a basic investigation from API evidence: find the record, name the identity and connect the Pod, the node and the time to other sources.

## Common pitfalls

> [!WARNING]
> - **Matching events by an exact timestamp.** Clocks differ between nodes. Use a window.
> - **Concluding that nothing happened because there is no record.** The policy may not cover the behavior, or the behavior may not use the API.
> - **Deleting the Pod before you read it.** The Pod object and its container IDs are evidence. Capture them first.
> - **Trusting a log that the attacker can change.** Keep a copy outside the cluster.
