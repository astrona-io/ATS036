---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Attribute An API Attempt To A Workload Identity

Classify a real denied Secret request and bind the finding to its actor and audit identifier.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-01-01" || exit 1
node_name="astro-ats-036-lab-030-01-01-control-plane"
worker_name="astro-ats-036-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Use the API audit log to identify the threat-reader ServiceAccount request denied with status 403 for the disposable audit-token Secret. Create audit-finding with actor, resource, namespace, code, finding unauthorized-secret-read, auditID, stage and requestURI matching the actual record. Keep the credential body out of the report. This is API behavioral evidence; it does not claim kernel-level syscall detection or establish a complete attack timeline from one event.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
