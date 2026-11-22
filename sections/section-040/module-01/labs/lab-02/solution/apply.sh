#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-01-02}"
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
echo "=== CAPTURE l1-mutable-pods"
kubectl -n starfleet-036-040-01-02 get pods -o custom-columns='NAME:.metadata.name,READONLY:.spec.containers[*].securityContext.readOnlyRootFilesystem'
echo "=== CAPTURE l1-label"
kubectl label namespace starfleet-036-040-01-02 immutability=enforced 2>&1
echo "=== CAPTURE l1-label-check"
kubectl get namespaces -l immutability=enforced
echo "=== CAPTURE l1-apply-policy"
kubectl apply -f validatingadmissionpolicy-require-read-only-root.yaml 2>&1
echo "=== CAPTURE l1-apply-binding"
kubectl apply -f validatingadmissionpolicybinding-require-read-only-root.yaml 2>&1
sleep 10
echo "=== CAPTURE l1-dry-run-starfleet-writable"
kubectl -n starfleet-036-040-01-02 create --dry-run=server -f pod-writable-check.yaml 2>&1; echo "exit: $?"
echo "=== CAPTURE l1-dry-run-starfleet-read-only"
kubectl -n starfleet-036-040-01-02 create --dry-run=server -f pod-read-only-check.yaml 2>&1; echo "exit: $?"
echo "=== CAPTURE l1-dry-run-outpost-writable"
kubectl -n outpost-036-040-01-02 create --dry-run=server -f pod-writable-check.yaml 2>&1; echo "exit: $?"
echo "=== CAPTURE l1-running-pods"
kubectl -n starfleet-036-040-01-02 get pods
bash "$solution_directory/apply.real.sh" 2>&1

echo "=== CAPTURE end"
exit 1
