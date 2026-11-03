---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Who Can Read Secrets

A Secret is protected by the API server, not by the Secret itself. If an account is allowed to read it, the API server returns the value. A review of data access therefore asks which accounts can read Secrets and which binding gives them that right. This part tests two accounts with `kubectl auth can-i`, finds the RoleBinding that grants the access, and explains why `list` is as dangerous as `get`.

## Roles and bindings

RBAC (role-based access control) has four objects. A Role holds a list of rules, and each rule names API groups, resources and verbs. A RoleBinding connects a Role to subjects, which are users, groups or ServiceAccounts, in one namespace. A ClusterRole and a ClusterRoleBinding do the same across the whole cluster. RBAC only adds permissions; it has no deny rule.

In the playground, the Role `secret-reader` allows the verbs `get` and `list` on `secrets`, and the RoleBinding `reporter-secrets` gives it to the ServiceAccount `reporter`. The Role `pod-reader` allows `get` and `list` on `pods`, and the RoleBinding `auditor-pods` gives it to `auditor`.

## Ask the API server

Reading the YAML tells you what was written. Asking the API server tells you what is enforced. The command `kubectl auth can-i` asks the server whether an action is allowed, and `--as` sends the question for another identity:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-020-03)"
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:reporter
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:auditor
```

The first command prints `yes`. The second prints `no` and exits with status 1, so a script can use the exit status. Your own account needs permission to impersonate, which a cluster administrator has.

To see everything an account may do in a namespace, list it:

```sh
kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:auditor
```

The output is a table of resources and verbs. It includes the rules from `pod-reader` and some default rules that every authenticated account receives. Compare the table with what the workload needs.

## Find the binding that grants the access

When `can-i` answers `yes`, find the rule behind it. List the RoleBindings with their Roles and subjects:

```sh
kubectl -n starfleet get rolebindings -o wide
```

The row for `reporter-secrets` shows the Role `secret-reader` and the subject `starfleet/reporter`. To revoke the access, delete this RoleBinding. Deleting the Role would also remove the access, but it would affect every other binding to it. Check cluster-wide bindings as well, because a ClusterRoleBinding can grant the same right in every namespace:

```sh
kubectl get clusterrolebindings -o wide
```

## Why list is as dangerous as get

The verb `get` reads one Secret by name. The verb `list` returns all Secrets of a namespace, and the response contains the data of each one. An account that can only `list` Secrets can still read every value. The verb `watch` returns the same data as a stream. A review that checks only for `get` misses two verbs.

Wildcards need the same care. A rule with `resources: ["*"]` or `verbs: ["*"]` includes Secrets, even if no rule names them. Also, the right to create Pods in a namespace is a path to Secrets, because the new Pod can mount any Secret there.

You can now test an account against the API server, find the binding behind an access and name the verbs that expose data. The next step is to look at the places where a Secret value becomes readable without any API permission.

## Common pitfalls

> [!WARNING]
> - **Trusting a Role name.** `secret-reader` is only a name. Test with `kubectl auth can-i`.
> - **Checking only `get`.** `list` and `watch` also return Secret data.
> - **Deleting the Role instead of the binding.** Other subjects may use the Role.
> - **Forgetting cluster-wide bindings.** A ClusterRoleBinding grants access in every namespace.
