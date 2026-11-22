#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-03-02}"
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
echo "=== CAPTURE limits"
kubectl -n starfleet-036-030-03-02 get pods -o custom-columns=NAME:.metadata.name,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory 2>&1
echo "=== CAPTURE reasons"
kubectl -n starfleet-036-030-03-02 get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason 2>&1
kubectl apply -f "$solution_directory/configmap-impact-report.yaml" 2>&1
echo "=== CAPTURE set-resources"
kubectl -n starfleet-036-030-03-02 set resources deployment/cruncher -c worker --requests=cpu=10m,memory=16Mi --limits=cpu=200m,memory=64Mi 2>&1
kubectl -n starfleet-036-030-03-02 rollout status deployment/cruncher --timeout=120s 2>&1
echo "=== CAPTURE apply-limitrange"
kubectl apply -f "$solution_directory/limitrange-container-limits.yaml" 2>&1
echo "=== CAPTURE dry-run"
kubectl -n starfleet-036-030-03-02 run limit-trial --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -o jsonpath='{.spec.containers[0].resources}{"\n"}' -- sleep 1 2>&1

echo "=== CAPTURE end"
exit 1
