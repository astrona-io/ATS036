---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Prerequisites

Use a host shell with astrona, kubectl and Python 3.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-02-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

You need to know two things before you start. Pod Security Admission is the admission controller built into the API server that checks each new Pod against a Pod Security Standard chosen by a namespace label. A server-side dry run (`kubectl create --dry-run=server`) sends an object through admission but does not store it.
