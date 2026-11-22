---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Prerequisites

Use astrona, kubectl, Python 3, Podman and a shell. The audit log lives on the control plane node, which is a container of this lab. Commands that read it run in that container, not on your own operating system.

A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. Select the lab's private kubeconfig and set the name of the control plane node container:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-050-01-02" || exit 1
node_name="astro-ats-036-lab-050-01-02-control-plane"
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.
