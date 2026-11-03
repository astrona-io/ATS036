---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Contain A Persistent Workload And Its Binding

Find the controller and binding behind an unexpected Pod, record them and contain both.

## Starting state

The isolated environment runs the `cache-sync` Deployment with one replica, which uses the `build-helper` ServiceAccount, and two RoleBindings in the `starfleet` namespace. The `cache-sync` Deployment is not part of the application. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-02-01" || exit 1
node_name="astro-ats-036-lab-030-02-01-control-plane"
worker_name="astro-ats-036-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Find the Deployment that creates the unexpected `cache-sync` Pod, the ServiceAccount it runs as, the RoleBinding that gives that ServiceAccount its permissions and the ClusterRole in that binding. Create the ConfigMap `persistence-finding` in `starfleet` with the keys `deployment`, `serviceAccount`, `binding`, `clusterRole` and `finding` (the value `persistence-and-escalated-authority`). Then contain the incident: scale the Deployment to zero replicas and delete the RoleBinding you found. Do not delete the Deployment, and leave the RoleBinding `probe-reader-view` unchanged.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
