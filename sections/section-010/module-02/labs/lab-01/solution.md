---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Write A Scoped Shell Detection Rule Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-02-01" || exit 1
node_name="astro-ats-036-lab-010-02-01-control-plane"
worker_name="astro-ats-036-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. No detection rule has been stored yet. The environment does not run Falco, so the rule is stored as text in a ConfigMap and checked for its fields.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl -n starfleet get configmaps
```

The rule file is a list with one rule. The condition combines the macros `spawned_process` and `container` with a namespace test and a list of shell names. The output names the pod and the command line so that an analyst can start triage from the alert alone.

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

```sh
kubectl apply -f configmap-shell-rule.yaml
```


## Verify The Result

Read the stored rule back and confirm that the condition, output and priority are present.

```sh
kubectl -n starfleet get configmap shell-in-probe-rule -o jsonpath='{.data.rules\.yaml}'
kubectl -n starfleet get deployment probe
```

The ConfigMap only stores the text. Falco applies a rule file after it is loaded with the `-r` option or mounted in the rules directory, and a rule that Falco has not loaded detects nothing.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-010-02-01`.

## Common pitfalls

> [!WARNING]
> A condition without the `container` macro also matches shells on the node itself. A condition without the namespace test matches every namespace. Keep the shell list as short as the baseline allows, and do not edit the probe Deployment to make the rule match.
