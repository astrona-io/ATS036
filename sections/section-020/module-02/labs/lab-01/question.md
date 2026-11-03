---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Report A Risky Pod Specification

Record the risky settings of a Pod from its specification. Use the isolated `starfleet` environment to verify the result.

## Objective

Record the risky settings of a Pod from its specification.

## Starting state

Pod `suspect-pod` runs a container with extra privileges and mounts a directory of the node. Pod `login-service` and the healthy probe application are separate from that evidence Pod.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Leave Pod `suspect-pod` running. Read its specification. Create ConfigMap `pod-risk-report` with `pod: suspect-pod`, `privileged` matching the container `securityContext`, and `hostPath` matching the node directory that the Pod mounts. Do not delete or change the evidence Pod.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
