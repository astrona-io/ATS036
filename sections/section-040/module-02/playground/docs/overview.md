---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Guided Practice: Drop All Capabilities And Block Privilege Escalation

Use a host shell with this environment's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the graded labs.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-playground-040-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Inspect the relevant evidence:

```sh
kubectl -n starfleet get pods
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.containers[0].securityContext}{"\n"}'
```

Capabilities are set per container, and the user is set for the Pod. The fields `CapBnd`, `CapEff` and `NoNewPrivs` in `/proc/1/status` show what the running process holds. Verify the process, not only the Pod object.

Save this as `pod-capability-free.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-free
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: worker
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
  securityContext:
    runAsNonRoot: true
    runAsUser: 2000
    runAsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
```

Apply the required change:

```sh
kubectl apply -f pod-capability-free.yaml
```

## Verify The Result

Observe the actual result. A denied-request command returns a nonzero status when the denial works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/capability-free --timeout=180s
kubectl -n starfleet exec capability-free -- id -u
kubectl -n starfleet exec capability-free -- sh -c "awk '/^CapEff/ {print \$2}' /proc/1/status"
kubectl -n starfleet exec capability-free -- sh -c "awk '/^CapBnd/ {print \$2}' /proc/1/status"
kubectl -n starfleet exec capability-free -- sh -c "awk '/^NoNewPrivs/ {print \$2}' /proc/1/status"
```

Create Pod `capability-free` running BusyBox as user and group 2000, with `runAsNonRoot: true` and RuntimeDefault seccomp. Its container `worker` must disable privilege escalation and drop all capabilities. The process must hold no capability, `no_new_privs` must be set, and the Pod must stay running.

## Common pitfalls

> [!WARNING]
> Dropping capabilities does not change the user, and a non-root user does not remove capabilities. Set both, add `allowPrivilegeEscalation: false`, and read `/proc/1/status` to confirm the process.
