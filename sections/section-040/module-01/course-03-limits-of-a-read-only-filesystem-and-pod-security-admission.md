---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Limits Of A Read-Only Filesystem And Pod Security Admission

A read-only root filesystem is one control, not a full defence. This part lists what it does not cover and shows how Pod Security Admission, the built-in admission controller, enforces a standard set of Pod restrictions for a whole namespace.

## What a read-only root does not cover

| Still possible | Why |
| --- | --- |
| Writes to mounted volumes | A volume is a separate filesystem. `emptyDir`, `hostPath` and persistent volumes accept writes if the user has rights. |
| Code that runs from memory | A process can load code into memory without a file. The filesystem setting does not see it. |
| Interpreters running commands | A shell or a language runtime that is already in the image can run attacker input as a script. |
| Network actions | The container can still connect to other services. |
| Reading secrets | Read-only does not hide mounted Secrets or the ServiceAccount token. |
| Writes through a `hostPath` mount | A Pod can write to the host filesystem if the volume points there. |

The lesson is to layer controls. Keep images small, with no shell or package manager if the application does not need one, and combine the read-only root with network policies, minimal RBAC and runtime detection.

## Pod Security Admission

Pod Security Admission checks each new Pod against one of three Pod Security Standards:

| Standard | Meaning |
| --- | --- |
| `privileged` | No restrictions. |
| `baseline` | Blocks known privilege escalations such as host namespaces and privileged containers. |
| `restricted` | Follows current hardening practice. It requires non-root, no privilege escalation, dropped capabilities and a seccomp profile. |

A namespace label selects the standard and the mode. The modes are `enforce` (reject the Pod), `audit` (allow and add an audit annotation) and `warn` (allow and show a warning to the user). The label key has the form `pod-security.kubernetes.io/<mode>`.

An important detail: the `restricted` standard does not require `readOnlyRootFilesystem`. A Pod can pass `restricted` and still have a writable root filesystem. The next part shows how to enforce that field.

## Try the restricted standard in a new namespace

Create a namespace that enforces `restricted`:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-040-01)"
kubectl config current-context
kubectl create namespace sealed
kubectl label namespace sealed pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest
```

Save this as `plain-pod.yaml`. It has no security context:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: plain-pod
  namespace: sealed
spec:
  containers:
    - name: main
      image: docker.io/library/busybox:1.37.0
      command: ["sleep", "3600"]
```

Apply it:

```sh
kubectl apply -f plain-pod.yaml
```

The API server rejects the Pod with a `forbidden` error. The message names the policy, `restricted:latest`, and lists each violated check, such as `allowPrivilegeEscalation != false`, unrestricted capabilities, `runAsNonRoot != true` and a missing `seccompProfile`.

Now save the same Pod with the missing fields as `compliant-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: sealed
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: main
      image: docker.io/library/busybox:1.37.0
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
```

Apply it:

```sh
kubectl apply -f compliant-pod.yaml
```

The Pod is accepted. Then check the root filesystem of the accepted Pod:

```sh
kubectl -n sealed wait --for=condition=Ready pod/compliant-pod --timeout=90s
kubectl -n sealed exec compliant-pod -- sh -c 'echo test > /root-file && echo written'
```

The write succeeds and the command prints `written`. The Pod passes `restricted`, yet its root filesystem is writable. Pod Security Admission does not replace `readOnlyRootFilesystem`.

## Scope of Pod Security Admission

Pod Security Admission looks at Pod specifications when a Pod is created. It does not stop existing Pods when you add a label. For workload objects such as a Deployment, it only produces `warn` and `audit` messages, because the Deployment itself is accepted and the controller creates the Pods later. Use `warn` and `audit` first on a namespace that has workloads, read the messages, fix the specifications, and then switch to `enforce`.

## Common pitfalls

> [!WARNING]
> - **Assuming `restricted` makes the filesystem read-only.** It does not. Add the field yourself or enforce it with a policy.
> - **Labelling a namespace with `enforce` and expecting running Pods to stop.** Existing Pods continue. Only new Pods are checked.
> - **Enforcing at once in a busy namespace.** The controller cannot create Pods and the rollout stalls. Start with `warn` and `audit`.
> - **Using the `latest` version label for stable behaviour.** `latest` follows the policy of the current Kubernetes version. Pin a version label when you need the same result across upgrades.
> - **Treating the system namespaces like application namespaces.** Components in `kube-system` need privileges. Do not enforce `restricted` there.
