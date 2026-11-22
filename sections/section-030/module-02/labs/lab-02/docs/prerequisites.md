---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Prerequisites

Use astrona, kubectl and a shell. The lab needs no access to the node containers.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-02-02" || exit 1
```

Keep this connection selected for the whole task.
