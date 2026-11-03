---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Summary

Every request to the Kubernetes API has an identity. People are known only through their credentials, and a ServiceAccount is an API object whose user name has the form `system:serviceaccount:<namespace>:<name>`. The kubelet mounts the token of a Pod's ServiceAccount into the container, so a shell in the container acts with the permissions of that account. A Pod that does not call the API can run without the token by setting `automountServiceAccountToken: false`.

RBAC adds permissions through Roles and RoleBindings, and it has no deny rule. The command `kubectl auth can-i` with `--as` asks the API server what an account may do, which is more reliable than reading Role names. The verbs `get`, `list` and `watch` all return Secret data, wildcards include Secrets, and the right to create Pods in a namespace is a path to every Secret there. Revoking an access means deleting the binding that grants it, after checking cluster-wide bindings too.

A Secret value is base64 text, not encrypted text. It can be read through the API, from the environment or files of a Pod, from etcd and from logs when an application prints it. Each path has its own control: RBAC, encryption at rest, limits on `exec` and file permissions, and careful logging. The key facts to remember are these:

- Name the identity in its full form before you check its access.
- Test access with the API server instead of reading YAML.
- `list` and `watch` expose data as well as `get`.
- The right to run commands in a Pod is a right to read what the Pod can read.

<!-- astrona:playground:destroy -->
