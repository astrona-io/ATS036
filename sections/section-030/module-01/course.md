---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Reconstructing Attack Phases And Actor Authority

An investigation starts with one observation, for example a denied request, and has to answer larger questions. How did the attacker get in, what did they try next, which identity did they use, and what can that identity still do? Deleting the suspicious Pod answers none of these questions, and a controller often creates the same Pod again.

This module teaches a method. You name the phase of an attack that an observation belongs to. You read the actor identity in an audit record and state what it proves. You merge records from several sources into one timeline. Then you contain the incident in an order that keeps the evidence and removes the attacker's authority.

The four parts are: **Attack Phases In Kubernetes**, which maps attacker goals to Kubernetes actions; **Actor Identity In Audit Records**, which reads the user, groups, source address and token details of a request; **Building A Timeline From Several Sources**, which orders events from audit records, object metadata and logs; and **Containment And Evidence Preservation**, which separates preserving, isolating, revoking and removing.

## Learning objectives

After this module you can:

- Map an observed action to a phase of an attack, such as discovery, credential access or persistence.
- Read the user, groups, source address and user agent of an audit event, and say what they do and do not prove.
- Build a timeline from audit records, object metadata and container logs, and mark each statement as fact or hypothesis.
- Find the controller that recreates a Pod and the permissions of the identity that was used.
- Contain an incident in the order preserve, isolate, revoke, remove.

## Before you start

You need Kubernetes basics: Pods, Deployments, ReplicaSets, ServiceAccounts, RBAC (role-based access control) and the commands `kubectl get`, `kubectl exec` and `kubectl auth can-i`. You also need to know that the Kubernetes API server can write an audit log.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. The API server writes an audit log to the control plane node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The `threat-client` Pod, which runs as the `threat-reader` ServiceAccount and has already tried to read the Secret `audit-token`. The Secret `audit-token` |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl` and `podman`. Host commands that touch a node name only this playground's node containers.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
