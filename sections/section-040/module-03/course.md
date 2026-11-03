---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Host Mounts And Replacement-Based Updates

A container is only immutable if the places it can write are controlled and if every change reaches it through a new container. Two weak points remain after the filesystem and the privileges are fixed. A volume that points at the node lets the container write outside its own filesystem. A fix applied by hand inside a running container creates a workload that no reviewed definition describes. This module closes both.

You will see how `hostPath` volumes reach the node and how a read-only mount limits them, then how a Deployment replaces containers instead of changing them, and finally how image digests and stored Pod fields show whether the running containers are the ones you approved.

The three parts are: **Volumes That Reach The Host**, which shows the risk of `hostPath` and a read-only mount; **Updating By Replacement**, which changes a workload through its Pod template and watches the rollout; and **Pinning Images And Detecting Drift**, which compares the image that runs with the image that was approved.

## Learning objectives

After this module you can:

- Explain why a `hostPath` volume breaks container isolation.
- Mount a volume read-only and show that a write fails.
- Change a workload by editing its Deployment template and read the rollout.
- Show that a manual change inside a Pod does not survive a replacement.
- Compare the image digest that runs with the image in the Pod template.

## Before you start

You need Kubernetes basics: Pods, Deployments, volumes and the commands `kubectl apply`, `kubectl get`, `kubectl exec` and `kubectl rollout`. You do not need to know how images are built.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
