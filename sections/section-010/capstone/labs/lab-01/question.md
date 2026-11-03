---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Report And Contain Suspicious Behavior From Audit Evidence

Report a denied Secret request and an exec into a probe Pod from the audit log, then quarantine the Pod without deleting it.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and three Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet namespace. Setup has produced two events: the threat-reader ServiceAccount asked for the audit-token Secret and was denied, and one `kubectl exec` ran a command in a probe Pod. Nothing has been reported or contained yet.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-010)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-010" || exit 1
node_name="astro-ats-036-capstone-010-control-plane"
worker_name="astro-ats-036-capstone-010-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the ConfigMap incident-report in the starfleet namespace with the keys deniedActor, deniedAuditID, execActor, execAuditID, execStage, podName and response. Copy deniedActor and deniedAuditID from the `ResponseComplete` record of the denied (403) Secret request, and execActor, execAuditID, execStage and podName from the audit record of the `exec` request. The value of response is quarantined.

Then quarantine the Pod named in podName: remove its `app` and `release` labels and add the label `quarantine=true`, so that the probe Service stops sending requests to it. Do not delete the Pod, because it is evidence. The probe Deployment must end with two running replicas that are not the quarantined Pod. Do not copy any request or response body.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
