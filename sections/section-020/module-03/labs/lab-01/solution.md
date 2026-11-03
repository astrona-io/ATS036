---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find Which Account Can Read Secrets Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

The namespace `starfleet` holds Secret `db-credentials` and two ServiceAccounts, `reporter` and `auditor`. One of them can read Secrets. Pod `data-client` and the healthy probe application are separate from that evidence.

Inspect the relevant evidence. The option `--as` makes `kubectl` send the request as another identity (impersonation), so the API server answers for that account:

```sh
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:reporter
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:auditor
kubectl -n starfleet get rolebindings -o wide
```

The first command prints `yes` and the second prints `no`. The third command lists each RoleBinding with its Role and its subjects, so you can name the binding that gives `reporter` the access. Preserve the existing RBAC objects, because the task records them and does not change them.

Save this as `configmap-access-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: access-finding
  namespace: starfleet
data:
  subject: system:serviceaccount:starfleet:reporter
  verb: get
  resource: secrets
  binding: reporter-secrets
```

Apply the required change:

```sh
kubectl apply -f configmap-access-finding.yaml
```

## Verify The Result

Observe the actual result.

```sh
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:reporter
kubectl -n starfleet get configmap access-finding -o jsonpath='{.data}{"\n"}'
```

Do not change any RBAC object. Find the ServiceAccount that can `get` Secrets in `starfleet`. Create ConfigMap `access-finding` with `subject` set to its full user name (`system:serviceaccount:starfleet:<name>`), `verb: get`, `resource: secrets` and `binding` set to the name of the RoleBinding that grants the access.

After recording the result, remove this independent lab with `astrona destroy ats-036-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> A ServiceAccount user name has the form `system:serviceaccount:<namespace>:<name>`, not just the short name. Check the answer with `kubectl auth can-i` instead of reading Role names alone, because a Role name does not prove what the Role allows.
