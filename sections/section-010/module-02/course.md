---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Writing Runtime Detection Rules

A runtime sensor is only as useful as its rules. A default rule set knows nothing about your namespaces, your workloads or your approved exceptions, so it reports too much in some places and too little in others. A rule that you write yourself states exactly which behavior is suspicious, where it applies and what the alert must tell the analyst.

This module teaches how to write that rule and how to prove that it works. You learn the parts of a Falco rule file: rules, macros and lists. You write a rule that is scoped to one namespace and to one behavior, and you store it. Then you add exceptions for approved behavior and learn what a rule can and cannot prove. Finally, you run Falco in a Linux virtual machine (VM) and check the rule against real kernel events, first for a Linux account and then for a Kubernetes namespace and Pod.

The five parts are: **Anatomy Of A Falco Rule File**, which explains the fields and shows how to choose them from a running container; **Scope A Shell Rule To A Namespace**, which builds the rule step by step; **Exceptions, Testing And Limits Of A Rule**, which covers approved exceptions, validation and coverage gaps; **Test A Live Sensor In A Linux VM**, which proves with a positive case that a running Falco sensor matches a shell and skips an approved command; and **Join A Runtime Event To Kubernetes Identity**, which adds the namespace, Pod name and Pod UID to each event through Falco's container plugin. The last two parts use their own VM, not the kind playground.

## Learning objectives

After this module you can:

- Name the parts of a Falco rule file and say what each part does.
- Choose rule fields from the processes that a container really runs.
- Write a rule condition that is limited to containers, a namespace and a set of process names.
- Write an alert output that gives an analyst the pod, the process and the command line.
- Add an exception for approved behavior without disabling the rule.

## Before you start

You need Kubernetes basics: Pods, Deployments, namespaces and the commands `kubectl get` and `kubectl exec`. You do not need to know Falco. Falco is not installed in the playground, so the rule files are stored as text in a ConfigMap and checked for their fields. Falco reads a rule file when it starts and does not read a ConfigMap by itself.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client |
| `outpost` | The `drifter` Pod, a BusyBox client |

The `probe` Pods run a small Python web server. Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
