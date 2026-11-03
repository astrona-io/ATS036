---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Impact And Resource Abuse

Impact is the phase in which the attacker reaches the goal: using the cluster for their own computing, destroying or changing data, or making a service stop. Some impact is quiet, such as a miner that uses spare CPU. This part lists the common kinds of impact and the commands that show their effects on Pods and nodes.

## Kinds of impact

Each kind of impact leaves a different mark.

| Impact | What you may see |
| --- | --- |
| Resource hijacking | High CPU use of a Pod that has no reason for it, Pods without resource limits, new Pods in the namespace |
| Denial of service | Pods that restart, Pods in `CrashLoopBackOff`, a node under memory pressure |
| Data destruction | Deleted objects in the audit log, empty volumes, Jobs that run a delete command |
| Data theft | Large outbound transfers, reads of many Secrets or ConfigMaps in the audit log |

A cluster rarely gives one clear signal. You combine small signals and decide which ones fit.

## Find Pods that can cause harm quietly

A container without resource limits can take all CPU and memory of its node. List the requests and limits of every container:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-030-03)"
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory
```

A value of `<none>` means no limit is set. The `probe` Pods have a memory limit but no CPU limit. The `intruder` Pod has no limit at all. In a real cluster, a ResourceQuota (a cap on the total resources of a namespace) and a LimitRange (default and maximum limits per container) reduce what one workload can take.

## Restarts and the reason for a kill

When a container uses more memory than its limit, the kernel stops it and Kubernetes records the reason. Print the restart count and the last termination reason of every container:

```sh
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason
```

A `LAST_REASON` of `OOMKilled` means the container exceeded its memory limit. A high restart count with `Error` points to a program that fails. Neither value proves an attack, and both are worth a closer look at the Pod with `kubectl describe pod`.

## Events and node pressure

Kubernetes events record scheduling, killing and evictions for a short time, usually one hour. Print the recent warnings of all namespaces, and the resource summary of the node:

```sh
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp
kubectl describe node | grep -A 8 "Allocated resources"
```

An empty list of warnings is a valid result in a healthy playground. The allocated resources section compares the requests and limits of all Pods with the capacity of the node. A limit total far above the capacity means that Pods can compete for the node when they all use their limits.

The command `kubectl top pods` shows live use, but it needs the Metrics Server add-on, which this playground does not install. In a real cluster, compare live use with the normal baseline of the workload.

You can now connect a suspicious Pod to its network source and look for its effects. The questions that remain are the ones of containment, which depend on what the evidence shows.

## Common pitfalls

> [!WARNING]
> - **Treating every restart as an attack.** Restarts come from bugs and limits as often as from attackers. Use the reason field.
> - **Relying on events.** Events expire after about an hour, so save them early.
> - **Looking only at CPU.** Memory, storage and network use are also targets of abuse.
> - **Assuming `kubectl top` works.** It needs the Metrics Server.
