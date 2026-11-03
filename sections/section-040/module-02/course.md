---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Dropping Privileges: Identity, Capabilities And Privilege Escalation

A read-only root filesystem stops a process from writing files, but it does not limit what the process is allowed to do. A process that runs as root with the default Linux capabilities can still change its identity, open raw network sockets, bypass file permission checks and, in a privileged container, reach the devices of the node. Immutability is only as strong as the privileges that remain. This module teaches how to remove those privileges.

You will see which Linux capabilities a container starts with and how to drop them, then how a non-root user and the `no_new_privs` flag stop a process from gaining rights it did not start with, and finally how privileged containers and added capabilities break those limits and how to find and block them.

The three parts are: **Linux Capabilities And What A Container Starts With**, which reads the capability sets of a real process and drops them; **Non-Root Identity And Privilege Escalation**, which builds a Pod that refuses to run as root and cannot escalate; and **Privileged Containers And Verifying Process Privileges**, which finds Pods with extra rights and blocks them with Pod Security Admission.

## Learning objectives

After this module you can:

- Name the main Linux capabilities that a container has by default and the risk of each.
- Drop all capabilities and read the result from `/proc/1/status`.
- Run a container as a non-root user and explain what `runAsNonRoot` checks.
- Explain what `allowPrivilegeEscalation: false` sets and what it prevents.
- Find privileged containers and added capabilities, and block them at admission.

## Before you start

You need Kubernetes basics: Pods, namespaces and the commands `kubectl apply`, `kubectl get`, `kubectl exec` and `kubectl delete`. You do not need to know how Linux capabilities are implemented.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
