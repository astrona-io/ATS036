---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Drop All Capabilities And Block Privilege Escalation

Run a workload as a non-root user with no Linux capabilities and no way to gain privileges. Use the isolated `starfleet` environment to verify the result.

## Objective

Run a workload as a non-root user with no Linux capabilities and no way to gain privileges.

## Starting state

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.


## Required result

Create Pod `capability-free` running BusyBox as user and group 2000, with `runAsNonRoot: true` and RuntimeDefault seccomp. Its container `worker` must disable privilege escalation and drop all capabilities. The process must hold no capability, `no_new_privs` must be set, and the Pod must stay running.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
