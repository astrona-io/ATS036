---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Scope A Shell Rule To A Namespace

A shell inside a web server container is one of the clearest signs of command execution. The rule that detects it can fail in two ways. If it matches too much, it reports every maintenance session. If it matches too little, it misses a shell started from a different binary name. This part builds a rule that is limited to containers, to one namespace and to a short list of shell names, and stores it in the cluster.

## Build the condition in steps

Start with the behavior: a new process. The macro `spawned_process` tests that an event is the creation of a process. This alone matches every process on the node, including the kubelet and the container runtime.

Add `container`. The condition `spawned_process and container` matches only processes inside containers. Host processes are no longer in scope.

Add the scope. The test `k8s.ns.name = starfleet` limits the rule to Pods of the `starfleet` namespace. A `shuttle` Pod in `starfleet` is in scope, and the `drifter` Pod in `outpost` is not. Use a different rule for other namespaces if their baseline differs.

Add the behavior. The test `proc.name in (sh, bash, ash)` matches the shell programs that a minimal Linux image can contain. The list is short on purpose. BusyBox provides `sh` and `ash`, and the Alpine-based `python` image provides `sh` and `ash`.

The complete condition is:

```text
spawned_process and container
and k8s.ns.name = starfleet
and proc.name in (sh, bash, ash)
```

Every part restricts the rule. The order does not change the result, but putting the cheapest tests first lets the sensor reject most events early.

## Write an output that supports triage

The output is the only text the analyst sees at first. It should answer where, what and by whom without a second search. Include the pod, the namespace, the process, the parent process, the command line, the user and the container ID.

The parent process matters. A shell with the parent `runc` or `containerd-shim` usually comes from `kubectl exec` or an `exec` health probe. A shell with the parent `python` was started by the application, which is much more suspicious in the `probe` workload.

## Store the rule

Save this as `configmap-shell-rule.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: shell-in-probe-rule
  namespace: starfleet
data:
  rules.yaml: |
    - rule: Shell started in probe namespace
      desc: A shell started inside a container of the starfleet namespace
      condition: >
        spawned_process and container
        and k8s.ns.name = starfleet
        and proc.name in (sh, bash, ash)
      output: >
        Shell started (pod=%k8s.pod.name namespace=%k8s.ns.name
        process=%proc.name parent=%proc.pname command=%proc.cmdline
        user=%user.name container=%container.id)
      priority: WARNING
      tags: [container, shell, mitre_execution]
```

Apply it:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-010-02)"
kubectl apply -f configmap-shell-rule.yaml
```

Then check the result:

```sh
kubectl -n starfleet get configmap shell-in-probe-rule -o jsonpath='{.data.rules\.yaml}'
```

The command prints the rule text exactly as stored. A ConfigMap is a place to keep and distribute the file. For the rule to detect anything, a Falco Pod must mount this ConfigMap in its rules directory and load the file when it starts.

The rule is now stored with a scoped condition and a useful output. What the rule cannot do yet is tolerate approved shells, and the next part adds that.

## Common pitfalls

> [!WARNING]
> - **Leaving out the `container` macro.** The rule then also fires for shells on the node.
> - **Leaving out the namespace test.** The rule fires in every namespace and teams stop reading it.
> - **Matching only `bash`.** Minimal images have `sh` and `ash` but not `bash`. Match the shells that the image can contain.
> - **Treating a stored rule as an active rule.** Storing text in the API does not load it into the sensor.
