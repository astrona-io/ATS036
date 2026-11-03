---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Privileged Containers And Verifying Process Privileges

Dropping capabilities, running as a non-root user and setting `no_new_privs` all remove rights from a container. This part looks at the opposite setting, a privileged container, which adds almost every right back. It shows how a Pod gets there by accident, how to find such Pods in a running cluster, and how Pod Security Admission blocks them before they start.

## What a privileged container is

The field `privileged: true` in the container `securityContext` asks the runtime for a container with nearly the same rights as a process on the node. The container gets all capabilities. It can see all the devices of the node under `/dev`. The default seccomp and AppArmor restrictions of the runtime do not apply to it. From such a container, an attacker can mount the disk of the node, load kernel modules or read the memory of other processes.

A privileged container makes those settings useless. Dropping capabilities and `no_new_privs` do not apply to it, because `privileged: true` overrides them. Some products ask for privileged mode, for example a network plugin or a storage driver. Those belong in a system namespace under review. A normal application never needs it.

Other fields add rights without the word privileged. These Pod settings also weaken immutability:

| Field | What it gives | Effect on immutability |
| --- | --- | --- |
| `capabilities.add: ["SYS_ADMIN"]` | Mount and other administrative actions | A process can mount a writable filesystem over a read-only path |
| `hostPID: true` | The process list of the node | A process can see and signal host processes |
| `hostNetwork: true` | The network namespace of the node | A process can reach services bound to the node interfaces |
| `hostPath` volume | A directory of the node | Writable access to node files |
| `allowPrivilegeEscalation: true` | The default value | A set-user-ID program can raise rights |

## Find Pods with extra rights

The stored Pod objects answer the question. Use `jsonpath` to print the container name and the fields that matter. A field that is not set prints as an empty value.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-040-02)"
kubectl get pods -A -o custom-columns='NAMESPACE:.metadata.namespace,POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,ESCALATION:.spec.containers[*].securityContext.allowPrivilegeEscalation,ADDED:.spec.containers[*].securityContext.capabilities.add'
```

Pods of the system namespaces, such as the network plugin or `kube-proxy`, may show `true` in the `PRIVILEGED` column. Those Pods are expected. For a namespace of applications, any `true` in `PRIVILEGED` or any entry in `ADDED` needs an explanation. The `ESCALATION` column is empty for most Pods. An empty value means the default, which is true.

## Block privileged Pods with Pod Security Admission

Pod Security Admission is the built-in admission controller that checks each new Pod against a Pod Security Standard. A namespace label chooses the standard and the action. The `baseline` standard forbids privileged containers, host namespaces, `hostPath` volumes and added capabilities outside a short list. The `enforce` mode rejects a Pod that breaks the standard.

Label the `outpost` namespace:

```sh
kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline
```

Save this as `privileged-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: outpost
spec:
  containers:
    - name: worker
      image: docker.io/library/busybox:1.37.0
      command: ["sleep", "3600"]
      securityContext:
        privileged: true
```

Apply it:

```sh
kubectl apply -f privileged-pod.yaml
```

The API server rejects the request. The error says that the Pod violates the `baseline` Pod Security Standard, and it names the `privileged` field of the container. The Pod is not created, so no container process ever runs with those rights. Pods that already run in the namespace are not stopped by the label. Pod Security Admission checks only new Pods.

Remove the label so that the namespace returns to its previous state:

```sh
kubectl label namespace outpost pod-security.kubernetes.io/enforce-
```

## Record the result

After a change, check the evidence on the running process, not only the Pod object. The two checks below together prove a hardened container. Run them against the `no-escalation` Pod, which runs as user 2000, drops all capabilities and sets `allowPrivilegeEscalation: false`:

```sh
kubectl -n starfleet exec no-escalation -- id -u
kubectl -n starfleet exec no-escalation -- grep -E 'CapEff|NoNewPrivs' /proc/1/status
```

The user ID is non-zero, `CapEff` is all zeros and `NoNewPrivs` is `1`. A process that shows these three values cannot write as root, cannot use a capability and cannot gain rights from a set-user-ID file.

This part completes the picture of privileges. A hardened container has a non-root user, no capabilities, `no_new_privs` and a seccomp filter. A Pod that asks for more is a finding, and admission can reject it. What remains is the filesystem behind the container, which the next module addresses.

## Common pitfalls

> [!WARNING]
> - **Reading the label as a removal.** Pod Security Admission does not stop or change Pods that already run. Check existing Pods separately.
> - **Using only `warn` or `audit` mode.** These modes record a violation but still create the Pod. Only `enforce` rejects it.
> - **Treating system Pods as findings.** Network plugins and storage drivers often run privileged. Review them, but judge them in their own namespace.
> - **Ignoring the empty `ESCALATION` column.** An empty value means the default, which allows escalation.
> - **Skipping the process check.** An object can look correct while the process still has rights. Read `/proc/1/status` for proof.
