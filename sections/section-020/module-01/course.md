---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Security Observability And Evidence Quality

A security team can only investigate what some component recorded. A Pod can be attacked at the node, in the application, on the network, in its data or through a user account, and each of these leaves a trace in a different place. Some traces are never written, and others are written and then lost to log rotation, a deleted Pod or a short retention time.

This module teaches where each kind of evidence lives in a Kubernetes cluster and how reliable it is. You will work from the layers of the environment to the commands that read their evidence, and you will learn to separate "nothing happened" from "nothing was recorded".

The three parts are: **Security Signals By Layer**, which maps infrastructure, applications, networks, data, users and workloads to their evidence sources; **Workload Logs, Restarts And Exit Evidence**, which reads container logs, restart counts and exit codes, including the log of the previous container instance; and **Network Traffic, Application Logs And Evidence Gaps**, which traces a request from a client Pod to a server Pod and lists the reasons why evidence can be missing.

## Learning objectives

After this module you can:

- Name the evidence source for threats at the infrastructure, application, network, data, user and workload layers.
- Read current and previous container logs, restart counts and exit codes with `kubectl`.
- Explain where container logs are stored on a node and when they are lost.
- Match an application log line to the Pod that sent the request.
- Decide whether a missing record means no activity or a collection gap.

## Before you start

You need Kubernetes basics: Pods, Deployments, Services, namespaces and the commands `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. It has no log collector, no runtime sensor and no audit log. That is on purpose: you will see what Kubernetes keeps by itself. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The `crash-report` Pod, which prints a line and exits with an error, so it restarts again and again |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl` and `podman`. Host commands that touch a node name only this playground's node containers.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
