---
draft: true
---
# Join A Runtime Event To Kubernetes Identity

A process event identifies what ran. Kubernetes metadata identifies the workload that owns that process. Falco's `k8smeta` plugin receives resource metadata from a collector and exposes fields such as namespace, Pod name and Pod UID. A Pod name can be reused after replacement; its UID identifies the particular object.

This independent VM runs Falco with a real kernel event source and the metadata collector. Run all commands inside it.

<!-- astrona:playground:renew -->

Select the cluster and inspect the sensor:

```sh
export KUBECONFIG=/etc/training/kubeconfig
kubectl -n falco get pods
kubectl -n monitored get pod reporter -o jsonpath='{.metadata.uid}'
cat /etc/training/values.yaml
```

Edit the `customRules.training.yaml` block in the values file. Preserve the surrounding driver, collector and output settings. The rule body is:

```yaml
- rule: Training namespace shell
  desc: Unexpected shells in the monitored training namespace
  condition: evt.type in (execve, execveat) and evt.dir = < and proc.name in (sh, bash) and k8smeta.ns.name = monitored and not proc.cmdline contains approved-
  output: Training shell (command=%proc.cmdline namespace=%k8smeta.ns.name pod=%k8smeta.pod.name uid=%k8smeta.pod.uid)
  priority: WARNING
```

Completed execution events use `evt.dir = <`. The namespace condition narrows detection; the command exception suppresses only the approved marker. This substring exception is deliberately visible training logic, not a recommended production allowlist for arbitrary user-controlled commands.

Load the changed values and restart the sensor so the test uses the new rule:

```sh
sudo helm --kubeconfig /etc/training/kubeconfig upgrade falco /etc/training/falco-9.2.2.tgz -n falco --reuse-values -f /etc/training/values.yaml --wait --timeout=8m
kubectl -n falco rollout restart daemonset/falco
kubectl -n falco rollout status daemonset/falco --timeout=300s
```

Allow about 15 seconds for metadata to populate. Generate a bounded set of events:

```sh
kubectl -n monitored exec reporter -- sh -c 'sleep 0.2' unexpected-student
kubectl -n monitored exec reporter -- sh -c 'sleep 0.2' approved-student
kubectl -n outside exec reporter -- sh -c 'sleep 0.2' outside-student
kubectl -n monitored exec reporter -- sh -c 'sleep 0.2' later-student
kubectl -n falco logs -l app.kubernetes.io/name=falco -c falco --since=30s --tail=-1
```

Find the custom rule's JSON records. Both unexpected monitored events should carry the live Pod UID; the approved and outside markers should have no record for this rule. Default rules may emit other events, so filter by rule name as well as marker.

## Common pitfalls

> [!WARNING]
> Missing metadata can make a namespace condition silently stop matching. Require positive events with populated identity before judging a quiet negative case. A later positive event also proves the sensor remained active through the exception test.
