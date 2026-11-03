---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Trace A Connection To Its Source Pod

Identify the Pod that sends unexpected requests to the probe Service and record its address.

## Starting state

The isolated environment runs the `probe` Deployment with two replicas and a Service in `starfleet`, and the idle Pods `shuttle` and `drifter`. One more Pod, in the `outpost` namespace, sends a request to the `probe` Service every five seconds. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-03-01" || exit 1
node_name="astro-ats-036-lab-030-03-01-control-plane"
worker_name="astro-ats-036-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Use the access log of the `probe` Pods to find the client address that sends the regular requests to `/`. Ignore the readiness probe requests of the kubelet. Map the address to a Pod. Create the ConfigMap `lateral-finding` in `starfleet` with the keys `sourcePod`, `sourceNamespace`, `sourceIP`, `target` (the value `probe`) and `finding` (the value `lateral-movement-to-probe`). Do not delete or change any Pod.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
