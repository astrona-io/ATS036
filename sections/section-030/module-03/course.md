---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Tracing Lateral Movement And Impact

After an attacker controls one Pod, the next steps are to reach other workloads and to cause harm. Both leave evidence in places that are not the audit log: the access logs of the target application, the Pod addresses of the network, and the resource use and restarts of the nodes.

This module teaches you to follow a connection from the target back to the Pod that made it, and to recognize the signs of impact. You read the access log of an application, map a client address to a Pod, and separate the requests of normal components from the requests of the intruder. Then you check resource limits, restarts and events for the effects of abuse.

The two parts are: **Lateral Movement And Network Evidence**, which maps client addresses in an application log to Pods; and **Impact And Resource Abuse**, which finds the effects of resource hijacking, destruction and denial of service.

## Learning objectives

After this module you can:

- Explain lateral movement and name the evidence it leaves in application logs and Pod addresses.
- Read the client address in an HTTP access log and map it to a Pod with `kubectl get pods -o wide`.
- Tell requests from the kubelet probes and from other cluster components apart from requests of an intruder.
- State what an absent log line does and does not prove.
- Find signs of impact: Pods without resource limits, restarts, `OOMKilled` containers and events.

## Before you start

You need to know Pods, Services, namespaces, Pod IP addresses, readiness probes and the commands `kubectl get`, `kubectl logs` and `kubectl describe`.

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control plane node and one worker node. These objects exist when you start:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas and a `probe` Service on port 80. The `shuttle` Pod, a BusyBox client that stays idle |
| `outpost` | The `drifter` Pod, a BusyBox client that stays idle. The `intruder` Pod, a BusyBox client that sends a request to the `probe` Service every five seconds |

Commands run from your host shell, which has `kubectl`.

Launch your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->
