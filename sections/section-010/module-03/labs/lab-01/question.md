---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Find The Audit Record Of A Pod Exec

Find the audit record of an interactive command run in a probe Pod and bind the finding to the identity and audit identifier.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet namespace. Setup has already run one `kubectl exec` into a probe Pod. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-03-01" || exit 1
node_name="astro-ats-036-lab-010-03-01-control-plane"
worker_name="astro-ats-036-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Use the API audit log to find the `create` request for the `exec` subresource of a probe Pod in the starfleet namespace. Create the ConfigMap exec-finding in the starfleet namespace with the keys actor, verb, resource, subresource, namespace, podName, finding, auditID, stage and requestURI, copied from the actual record. The value of finding is unexpected-exec. Use the stage that the API server logged for the request. Do not copy any request or response body. This is API evidence of who asked for a command; it does not show what the command did inside the container.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
