#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
engine="${engine:-${ASTRONA_CONTAINER_ENGINE:-podman}}"
cluster="${cluster:-${ASTRONA_KIND_CLUSTER:-}}"
set +e
exec 2>&1
cd "$solution_directory"
ns=starfleet-036-040-02-02
echo "=== CAPTURE l2-find-pods"
kubectl -n $ns get pods -o custom-columns='POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,HOSTPID:.spec.hostPID,ADDED:.spec.containers[*].securityContext.capabilities.add'
echo "=== CAPTURE l2-find-deployments"
kubectl -n $ns get deployments -o custom-columns='DEPLOYMENT:.metadata.name,CONTAINER:.spec.template.spec.containers[*].name,PRIVILEGED:.spec.template.spec.containers[*].securityContext.privileged'
echo "=== CAPTURE l2-capeff-before"
kubectl -n $ns exec deploy/telemetry-agent -- grep CapEff /proc/1/status 2>&1
echo "=== CAPTURE l2-apply-finding"
kubectl apply -f configmap-privilege-finding.yaml 2>&1
echo "=== CAPTURE l2-label"
kubectl label namespace $ns pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=latest 2>&1
echo "=== CAPTURE l2-pods-after-label"
kubectl -n $ns get pods
echo "=== CAPTURE l2-dry-run-privileged"
kubectl -n $ns create --dry-run=server -f pod-privileged-check.yaml 2>&1; echo "exit: $?"
echo "=== CAPTURE l2-apply-deployment"
kubectl apply -f deployment-telemetry-agent.yaml 2>&1
echo "=== CAPTURE l2-rollout"
kubectl -n $ns rollout status deployment/telemetry-agent --timeout=180s 2>&1
echo "=== CAPTURE l2-capeff-after"
kubectl -n $ns exec deploy/telemetry-agent -- grep CapEff /proc/1/status 2>&1
echo "=== CAPTURE l2-delete-inspector"
kubectl -n $ns delete pod node-inspector 2>&1
echo "=== CAPTURE l2-find-pods-after"
kubectl -n $ns get pods -o custom-columns='POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,HOSTPID:.spec.hostPID,ADDED:.spec.containers[*].securityContext.capabilities.add'
bash "$solution_directory/apply.real.sh" 2>&1

echo "=== CAPTURE end"
exit 1
