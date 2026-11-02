---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Behavioral Detection With Runtime Context

A scanner can approve an image and a policy can approve a Pod, and the container can still be attacked after it starts. A request that exploits the application may start a shell, read a file the application never reads, or call the Kubernetes API with the Pod's ServiceAccount token. Behavioral detection looks at what a running workload does and compares it with what the workload is supposed to do.

This module teaches that comparison in four steps. You describe the expected behavior of a workload. You learn how a runtime sensor such as Falco turns system calls into alerts. You read Kubernetes API audit records as a second source of behavioral evidence. Then you decide what to do with an alert: confirm it, tune the rule, and respond without destroying the evidence.

The four parts are: **Expected Behavior Of A Workload**, which builds a baseline from the Pod specification and the running processes; **Syscalls, eBPF And Falco Rules**, which explains how a sensor sees events and how a rule is written; **Audit Records As Behavioral Evidence**, which finds a denied API request in the audit log; and **Triage, Tuning And Response To An Alert**, which covers false positives, rule exceptions, evidence capture and quarantine.

## Learning objectives

After this module you can:

- Write down the expected processes, files, network connections and API calls of a workload.
- Explain how a system call becomes a Falco alert, and read the fields of a Falco rule.
- Find a denied API request in the Kubernetes audit log and name its actor, resource and result.
- Decide whether an alert is a false positive, and tune a rule without disabling it.
- Preserve evidence and quarantine a Pod without deleting it.

## Before you start

You need Kubernetes basics: Pods, Deployments, Services, namespaces, ServiceAccounts and the commands `kubectl get`, `kubectl logs` and `kubectl exec`. You do not need to know Falco. Falco is not installed in the playground, so the Falco rules in the second part are for reading; everything else in the module runs in the playground.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. The Kubernetes API server writes an audit log to the control plane node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The `threat-client` Pod, which runs as the `threat-reader` ServiceAccount. The Secret `audit-token` |
| `outpost` | The `drifter` Pod, a BusyBox client |

The `probe` Pods run a small Python web server. The `threat-client` Pod has already sent one request that the API server denied. Commands run from your host shell, which has `kubectl` and `podman`. Host commands that touch a node name only this playground's node containers.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
