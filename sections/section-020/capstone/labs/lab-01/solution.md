---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Triage Four Findings And Revoke Secret Access Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-020" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

A security review found four problems in the namespace `starfleet`. Pod `crash-report` keeps restarting. Pod `login-service` wrote many failed logins. Pod `suspect-pod` runs with extra privileges. The ServiceAccount `reporter` can read Secrets that it does not need. The ServiceAccount `auditor` has a legitimate, read-only Pod permission.

Inspect the evidence for each finding:

```sh
kubectl -n starfleet logs crash-report -c report --previous
kubectl -n starfleet get pod crash-report -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
kubectl -n starfleet logs login-service
kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}'
kubectl -n starfleet get rolebindings -o wide
```

The exit code of the previous container instance, the number of `login failed` lines, the privileged Pod and the RoleBinding that grants Secret access are the four values to record. Count the failed logins from the log itself, and do not count the line `login ok`.

Save this as `configmap-threat-register.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: threat-register
  namespace: starfleet
data:
  crashExitCode: '12'
  failedLogins: '5'
  privilegedPod: suspect-pod
  secretReader: reporter
```

Apply the register:

```sh
kubectl apply -f configmap-threat-register.yaml
```

Then remove the access that exposed the Secret. Deleting the RoleBinding removes the permission from `reporter` and leaves the Role and the other RoleBinding in place:

```sh
kubectl -n starfleet delete rolebinding reporter-secrets
```

## Verify The Result

Observe the actual result.

```sh
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:reporter
kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:auditor
```

The first command prints `no` and exits with status 1. The second prints `yes`.

Create ConfigMap `threat-register` with `crashExitCode` (the exit code of the previous instance of `crash-report`), `failedLogins` (the number of `login failed` lines in `login-service`), `privilegedPod` (the Pod name) and `secretReader` (the short name of the ServiceAccount that can read Secrets). Then delete RoleBinding `reporter-secrets`. Keep RoleBinding `auditor-pods`. Do not delete or change any Pod, because the Pods are the evidence.

After recording the result, remove this independent lab with `astrona destroy ats-036-capstone-020`.

## Common pitfalls

> [!WARNING]
> Delete only the RoleBinding that grants the unneeded access. Removing the `auditor-pods` binding breaks a legitimate permission, and deleting a Pod destroys evidence. Record the values from the evidence, not from the description of the task.
