---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Triage Four Findings And Revoke Secret Access

Record four findings from one cluster and revoke the access that exposed a Secret. Use the isolated `starfleet` environment to verify the result.

## Objective

Record four findings from one cluster and revoke the access that exposed a Secret.

## Starting state

A security review found four problems in the namespace `starfleet`. Pod `crash-report` keeps restarting. Pod `login-service` wrote many failed logins. Pod `suspect-pod` runs with extra privileges. The ServiceAccount `reporter` can read Secrets that it does not need. The ServiceAccount `auditor` has a legitimate, read-only Pod permission.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-020" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Create ConfigMap `threat-register` with `crashExitCode` (the exit code of the previous instance of `crash-report`), `failedLogins` (the number of `login failed` lines in `login-service`), `privilegedPod` (the Pod name) and `secretReader` (the short name of the ServiceAccount that can read Secrets). Then delete RoleBinding `reporter-secrets`. Keep RoleBinding `auditor-pods`. Do not delete or change any Pod, because the Pods are the evidence.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
