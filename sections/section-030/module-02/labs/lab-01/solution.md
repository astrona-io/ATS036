---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Contain A Persistent Workload And Its Binding Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-02-01" || exit 1
node_name="astro-ats-036-lab-030-02-01-control-plane"
worker_name="astro-ats-036-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment runs the `cache-sync` Deployment with one replica, which uses the `build-helper` ServiceAccount, and two RoleBindings in the `starfleet` namespace. The `cache-sync` Deployment is not part of the application. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -l app=cache-sync
kubectl -n starfleet get deployment cache-sync -o yaml
kubectl -n starfleet get rolebindings -o wide
```

Find the Deployment that creates the unexpected `cache-sync` Pod, the ServiceAccount it runs as, the RoleBinding that gives that ServiceAccount its permissions and the ClusterRole in that binding. Create the ConfigMap `persistence-finding` in `starfleet` with the keys `deployment`, `serviceAccount`, `binding`, `clusterRole` and `finding` (the value `persistence-and-escalated-authority`). Then contain the incident: scale the Deployment to zero replicas and delete the RoleBinding you found. Do not delete the Deployment, and leave the RoleBinding `probe-reader-view` unchanged.

Save this as `configmap-persistence-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: persistence-finding
  namespace: starfleet
data:
  deployment: cache-sync
  serviceAccount: build-helper
  binding: build-helper-edit
  clusterRole: edit
  finding: persistence-and-escalated-authority
```

Apply it:

```sh
kubectl apply -f configmap-persistence-finding.yaml
```

Contain the workload and the authority. Scaling to zero keeps the Deployment as evidence:

```sh
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit
```

## Verify The Result

Observe the actual result.

```sh
kubectl -n starfleet get configmap persistence-finding -o yaml
kubectl -n starfleet get pods,rolebindings
```

Check that no `cache-sync` Pod remains, that the Deployment still exists with zero replicas and that `probe-reader-view` is still present. Authorization is checked on every request, so deleting the binding ends the permissions of the ServiceAccount at once. No example command output is presented as evidence of a completed run.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-030-02-01`.

## Common pitfalls

> [!WARNING]
> Deleting the Pod does not stop the Deployment from creating another one. Remove the binding that belongs to the incident, not the normal one, and keep the Deployment so the template stays as evidence.
