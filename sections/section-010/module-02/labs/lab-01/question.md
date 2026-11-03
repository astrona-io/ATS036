---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Write A Scoped Shell Detection Rule

Write a runtime detection rule that reports shells started in the starfleet namespace.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. No detection rule has been stored yet. The environment does not run Falco, so the rule is stored as text in a ConfigMap and checked for its fields.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-02-01" || exit 1
node_name="astro-ats-036-lab-010-02-01-control-plane"
worker_name="astro-ats-036-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the ConfigMap shell-in-probe-rule in the starfleet namespace with one key, rules.yaml. The key holds one rule with a description, a condition, an output and a priority. The condition must match process creation inside containers (`spawned_process` and `container`), only in the starfleet namespace (`k8s.ns.name = starfleet`), and only for the shell names sh, bash and ash. The output must name the pod (`%k8s.pod.name`) and the command line (`%proc.cmdline`). The priority is WARNING. Do not change the probe Deployment.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
