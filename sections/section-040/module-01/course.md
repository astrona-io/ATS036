---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Constraining Runtime Mutation And Writable Paths

An image is built and reviewed before it runs, but a running container can change itself. A process with enough rights can write a new executable, edit a configuration file or install a tool. If an attacker gets a shell in the container, those writes are the first steps of persistence and privilege escalation. Container immutability closes this path: the container may run, but it may not change its own code.

This module teaches how to make containers immutable at runtime. You will see what a container can change by default, then set a read-only root filesystem with a writable scratch volume, then check what that setting does not cover, and finally verify and enforce the settings with Kubernetes admission controls.

The four parts are: **The Writable Container Layer**, which shows where a container writes by default and why replacing a container beats patching it; **Read-Only Root Filesystem And Security Context**, which builds a Pod that cannot write to its root filesystem; **Limits Of A Read-Only Filesystem And Pod Security Admission**, which covers writable mounts, privileges and the restricted Pod Security Standard; and **Verifying And Enforcing Immutability**, which checks image identity and exec rights and blocks mutable Pods with a ValidatingAdmissionPolicy.

## Learning objectives

After this module you can:

- Explain the writable container layer and why a container restart discards it.
- Set `readOnlyRootFilesystem`, a non-root user, dropped capabilities and a seccomp profile in a Pod.
- Give a mutable application the writable paths it needs with an `emptyDir` volume.
- Name what a read-only root filesystem does not protect against.
- Enforce the restricted Pod Security Standard and a rule for read-only root filesystems at admission.

## Before you start

You need Kubernetes basics: Pods, Deployments, namespaces, volumes and the commands `kubectl apply`, `kubectl get`, `kubectl exec` and `kubectl delete`. You do not need to know AppArmor or seccomp profile syntax.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client |
| `outpost` | The `drifter` Pod, a BusyBox client |

The `probe` Pods run a Python web server as the root user with default settings, so they are the example of a mutable container. Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
