---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Detecting Threats To Data And User Accounts

Data in a cluster is protected by identity: the API server decides who may read a Secret, and the Pod that holds a credential decides who can reach it from inside. A threat to data is therefore almost always a threat from an account that has more access than it needs, or from a place where the data is exposed in readable form.

This module teaches how to find both. You will start with the identities that exist in a cluster, human users and ServiceAccounts, and see how a Pod receives its identity. You will then review which accounts can read Secrets, with commands that ask the API server directly. Last you will follow the paths along which a Secret value becomes visible: the API, environment variables, volumes and logs.

The three parts are: **ServiceAccounts And User Identity**, which shows how identities are named and how a Pod gets a token; **Who Can Read Secrets**, which reviews RBAC (role-based access control) bindings and tests them with impersonation; and **Secret Exposure Paths**, which finds where a Secret value can be read and what limits that.

## Learning objectives

After this module you can:

- Write the user name of a ServiceAccount and find which ServiceAccount a Pod uses.
- Explain where a Pod receives its API token and how to stop it.
- Test whether an account can read Secrets with `kubectl auth can-i`.
- Find the RoleBinding that grants an access.
- List the paths along which a Secret value can be read.

## Before you start

You need Kubernetes basics: Pods, namespaces, Secrets, and the commands `kubectl get`, `kubectl describe` and `kubectl exec`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service. The `shuttle` Pod, a BusyBox client. The Secret `db-credentials`. The ServiceAccounts `reporter` and `auditor`, with the Roles `secret-reader` and `pod-reader` and their RoleBindings. The `data-client` Pod, which runs as `reporter` and reads the Secret into an environment variable |
| `outpost` | The `drifter` Pod, a BusyBox client |

Commands run from your host shell, which has `kubectl`. Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
