---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Finding Persistence And Escalated Authority

An attacker who has run code in one Pod wants two things: to stay in the cluster after that Pod is removed, and to hold more authority than the first foothold gave. In Kubernetes both goals leave objects behind. A controller template keeps starting the same container, and a binding keeps giving permissions to a ServiceAccount.

This module teaches you to find those objects and to remove them in a safe order. You follow the ownership chain from a running Pod to the object that recreates it. You read bindings and test what a ServiceAccount can do. Then you contain the incident without destroying the evidence.

The two parts are: **Persistence In Workload Templates And Schedules**, which lists the objects that restart attacker code and shows how to follow an owner reference; and **Privilege Escalation Through Bindings And Pod Settings**, which reads RBAC bindings and risky Pod settings and ends with a containment.

## Learning objectives

After this module you can:

- List the Kubernetes objects an attacker can use to persist: controller templates, CronJobs, bindings and token Secrets.
- Follow `ownerReferences` from a Pod to the controller that recreates it.
- Find the binding that gives a ServiceAccount its permissions and test the result with `kubectl auth can-i --as`.
- Name the Pod settings and RBAC verbs that give an attacker more authority.
- Contain a persistent workload by preserving it, scaling the controller to zero and removing the binding.

## Before you start

You need to know Pods, Deployments, ReplicaSets, ServiceAccounts, Roles, RoleBindings and the commands `kubectl get`, `kubectl describe` and `kubectl auth can-i`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `cache-sync` Deployment with one replica, which runs as the `build-helper` ServiceAccount. The RoleBinding `build-helper-edit`. The ServiceAccount `probe-reader` and the RoleBinding `probe-reader-view` |

The `cache-sync` Deployment is not part of the application. The RoleBinding `probe-reader-view` is a normal binding that you must leave alone. Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
