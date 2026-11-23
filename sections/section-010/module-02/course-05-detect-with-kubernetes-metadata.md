---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Join A Runtime Event To Kubernetes Identity

A process event says what ran on the node. It does not say which workload owns that process. To scope a rule to one namespace, Falco must add the Kubernetes identity of the container to each event. This lesson shows where those fields come from and how to prove that they are filled in.

## Where the Kubernetes fields come from

Falco 0.45 loads its container plugin by default. For each event from a container, the plugin asks the container runtime (containerd on a kubeadm node) for the container and reads the Pod labels that the kubelet sets on it. The plugin then adds fields such as `k8s.ns.name` (the namespace of the Pod), `k8s.pod.name` and `k8s.pod.uid`. The UID is the unique ID that Kubernetes gives each Pod. A Pod name can come back after the Pod is replaced, but the UID is new for each Pod, so the UID ties an alert to one exact object.

The lab VM for this lesson runs a one-node kubeadm cluster and Falco 0.45.2 as `falco-modern-bpf.service`. The namespaces `starfleet-036-010-02-03` and `outpost-036-010-02-03` each run a Pod named `reporter`. Open a shell on it with `astrona ssh astro-ats-036-lab-010-02-03` when the lab starts.

<!-- astrona:playground:renew -->

Print the UID of the monitored Pod and the current custom rule:

```sh
kubectl -n starfleet-036-010-02-03 get pod reporter -o jsonpath='{.metadata.uid}{"\n"}'
sudo cat /etc/falco/falco_rules.local.yaml
```

The rule file starts with a namespace that does not exist, so the rule matches nothing yet. The next step gives it the right namespace and the identity fields.

## A rule scoped to one namespace

The rule below matches the exit event (`evt.dir = <`) of `execve` or `execveat`, so it sees only a program start that the kernel completed. The namespace condition narrows it to one namespace. The command line exception skips only commands that contain `approved-`. This substring exception is visible training logic; it is not a safe production allowlist, because the person who runs the command controls the command line.

Save this as `falco-rules-local.yaml`:

```yaml
- rule: Training namespace shell
  desc: Unexpected shells in the monitored namespace
  condition: >
    evt.type in (execve, execveat) and evt.dir = < and proc.name in (sh, bash)
    and k8s.ns.name = starfleet-036-010-02-03 and not proc.cmdline contains approved-
  output: Training shell (command=%proc.cmdline namespace=%k8s.ns.name pod=%k8s.pod.name uid=%k8s.pod.uid)
  priority: WARNING
```

Copy it over the custom rule file, check it and restart Falco so that it loads the new rule:

```sh
sudo cp falco-rules-local.yaml /etc/falco/falco_rules.local.yaml
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
```

Falco reads its rule files only when it starts, so a changed file does nothing until the restart.

## Test with fresh events

Now start a shell for each case. The last word of each command line names the case, so you can find it in the alerts:

```sh
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' unexpected-student
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' approved-student
kubectl -n outpost-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' outside-student
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' later-student
sudo grep 'Training namespace shell' /var/log/falco-events.jsonl | tail -n 5
```

The alerts for `unexpected-student` and `later-student` carry the namespace, the name `reporter` and the UID that the first command printed. The approved and outside markers have no alert of this rule. Falco's default rules can raise other alerts for the same shells, so filter by the rule name as well as the marker.

You now know where Falco gets the Kubernetes identity of an event and how to prove it with a live Pod UID. The open question is what happens when that identity is missing, which the pitfalls below cover.

## Common pitfalls

> [!WARNING]
> Missing metadata can make a namespace condition silently stop matching: an empty `k8s.ns.name` never equals the namespace. Require positive events with filled identity fields before you trust a quiet negative case. A later positive event also proves the sensor stayed active through the exception test.
