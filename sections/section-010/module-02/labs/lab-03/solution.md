---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Scope Live Falco Events With Kubernetes Metadata Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-010-02-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-010-02-03`. Falco files and the Falco service belong to root, so the commands below use `sudo`.

## Fix the namespace and the output

Falco sees every process on the node, also the processes inside containers. Its container plugin looks up the container of each event in the container runtime and adds the Kubernetes fields. `k8s.ns.name` is the namespace of the Pod, `k8s.pod.name` its name and `k8s.pod.uid` its UID (the unique ID that Kubernetes gives each Pod). A Pod name can come back after the Pod is deleted, but the UID is new for each Pod, so the UID ties an alert to one exact Pod.

The rule below keeps the event filter of the starting rule and changes two things: the namespace in the condition and the fields in the output. `not proc.cmdline contains approved-` skips the approved commands only.

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

Copy it over the custom rule file:

```sh
sudo cp falco-rules-local.yaml /etc/falco/falco_rules.local.yaml
```

## Load the rule

`falco -V` checks a rule file and exits with an error if the file is not valid. Falco reads its rules only when it starts, so restart the service after the check:

```sh
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
sudo systemctl is-active falco-modern-bpf.service
```

The last command prints `active` once Falco runs again.

## Test the alerts

Print the UID of the monitored Pod, then start one shell for each case:

```sh
kubectl -n starfleet-036-010-02-03 get pod reporter -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' unexpected-check
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' approved-check
kubectl -n outpost-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' outside-check
kubectl -n starfleet-036-010-02-03 exec reporter -- sh -c 'sleep 0.2' later-check
sudo grep 'Training namespace shell' /var/log/falco-events.jsonl | tail -n 5
```

The alerts for `unexpected-check` and `later-check` show `namespace=starfleet-036-010-02-03`, `pod=reporter` and the UID that the first command printed. The same values are in `output_fields` under `k8s.ns.name`, `k8s.pod.name` and `k8s.pod.uid`. No alert names `approved-check` or `outside-check`. The last alert comes after the two negative cases, so it shows that Falco was still running when they ran.
