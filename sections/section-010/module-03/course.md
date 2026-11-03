---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Detecting Command Execution Through API Audit Records

A command run inside a Pod with `kubectl exec` is one of the most common ways to inspect a compromised workload, and it is also one of the most common ways an attacker with stolen credentials moves inside a cluster. The command runs inside the container, so Kubernetes does not log what it printed. The request that started it passes through the Kubernetes API server, and the API server can record that request.

This module teaches how to use those records as behavioral evidence. You learn what an `exec` or `portforward` request looks like in the audit log and which audit policy rule records it. You learn to read the identity and the origin of a request. Then you connect the audit record with other evidence and learn what the record cannot prove.

The three parts are: **Exec And Port-Forward In The Audit Log**, which finds a real `exec` request in the playground; **Who Sent The Request: Identity And Origin**, which reads the user, the groups, the source address and the client; and **Correlating Audit Records With Other Evidence**, which links the request to a Pod, a time window and a runtime alert.

## Learning objectives

After this module you can:

- Say which audit policy rule records `exec` and `portforward` requests.
- Find the audit record of a `kubectl exec` request and name its verb, resource, subresource and Pod.
- Name the authenticated user, groups, source address and client of a request.
- Bind a finding to an audit identifier and a stage without copying request content.
- Explain what an `exec` audit record proves and what it does not prove.

## Before you start

You need Kubernetes basics: Pods, Deployments, namespaces, users and ServiceAccounts, and the commands `kubectl get` and `kubectl exec`. You do not need to know the audit log format.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. The Kubernetes API server writes an audit log to the control plane node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The `threat-client` Pod. The Secret `audit-token` |
| `outpost` | The `drifter` Pod, a BusyBox client |

Setup has already run one `kubectl exec` into a `probe` Pod. Commands run from your host shell, which has `kubectl` and `podman`. Host commands that touch a node name only this playground's node containers.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
