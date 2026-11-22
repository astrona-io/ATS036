---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Prerequisites

Use a host shell with astrona, kubectl and Python 3.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-01-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

You need to know three things before you start. A ValidatingAdmissionPolicy is a built-in admission rule written in the Common Expression Language (CEL), and the API server evaluates it for each matching request. A ValidatingAdmissionPolicyBinding says where a policy applies and what the API server does when the expression is false. A server-side dry run (`kubectl create --dry-run=server`) sends the object through admission but does not store it.
