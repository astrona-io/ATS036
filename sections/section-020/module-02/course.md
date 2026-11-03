---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Detecting Risky Workloads From Events, Specifications And Logs

A workload that is already running can hold the first sign of an attack in three places: the events that Kubernetes wrote about it, the settings in its Pod specification, and the lines its application printed. None of the three needs a special sensor. All of them can be read with `kubectl`, and all of them can be lost or misread.

This module teaches how to read these three sources and how to decide what each one proves. You will start with Kubernetes events, which are short-lived records of what the control plane and the kubelet did. You will then read a Pod specification for settings that give a container more power than it needs, and last you will count and classify security-relevant lines in an application log.

The three parts are: **Kubernetes Events As A Short-Lived Signal**, which reads events for a Pod and explains how long they last; **Reading A Pod Specification For Risky Settings**, which finds a privileged container and a host directory mount; and **Application Log Signals Of Abuse**, which counts failed logins and explains what a count can and cannot prove.

## Learning objectives

After this module you can:

- Read the events of a Pod and name the component that wrote each one.
- Explain why events are not long-term evidence.
- Find privileged containers and host directory mounts in one Pod and in all namespaces.
- Explain what a Pod Security Admission level does with such settings.
- Count failed logins in a container log and decide when the count is a signal.

## Before you start

You need Kubernetes basics: Pods, namespaces, and the commands `kubectl get`, `kubectl describe` and `kubectl logs`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The `suspect-pod` Pod, which runs a privileged container and mounts the node directory `/etc`. The `login-service` Pod, which prints five failed logins and one successful login |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl`. Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
