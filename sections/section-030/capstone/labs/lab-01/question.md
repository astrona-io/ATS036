---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Investigate And Contain A Multi-Phase Incident

Combine audit, ownership, binding and network evidence into one incident report and contain the workload and its authority.

## Starting state

The isolated environment has the `probe` Deployment, the `shuttle` and `drifter` Pods, and the `threat-client` Pod that is denied when it reads the Secret `audit-token`. Three things are unexplained: the `cache-sync` Deployment in `starfleet`, which runs as the `build-helper` ServiceAccount; the RoleBinding that gives that ServiceAccount its permissions; and a Pod in `outpost` that sends a request to the `probe` Service every five seconds. The API server writes an audit log on the control plane node. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-030" || exit 1
node_name="astro-ats-036-capstone-030-control-plane"
worker_name="astro-ats-036-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the ConfigMap `incident-report` in `starfleet` with these keys: `actor` and `auditID` of the real audit record for the denied Secret read of `threat-reader`; `deployment` and `binding` of the persistence objects; `sourcePod`, `sourceNamespace` and `sourceIP` of the Pod that sends regular requests to the `probe` Service; `phases` with the value `credential-access,persistence,lateral-movement`; and `finding` with the value `multi-phase-incident`. Keep the content of the Secret out of the report. Then contain the incident: scale `cache-sync` to zero replicas, delete the RoleBinding of the incident, and label the intruding Pod `incident=quarantine` without deleting it. Do not delete the Secret `audit-token`, the `probe` Deployment or the RoleBinding `probe-reader-view`.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
