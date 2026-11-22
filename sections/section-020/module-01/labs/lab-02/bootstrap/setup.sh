#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-036-020-01-02"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl -n "$namespace" wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-036-020-01-02 wait --for=condition=Ready pod/drifter --timeout=120s
kubectl -n outpost-036-020-01-02 wait --for=condition=Ready pod/crash-report --timeout=120s

kubectl apply -f "$lab_directory/bootstrap/manifests/fault.yaml"
previous_instance_ready=0
for attempt in $(seq 1 60); do
  restart_count="$(kubectl -n "$namespace" get pod crash-report -o jsonpath='{.status.containerStatuses[0].restartCount}')"
  if [[ "${restart_count:-0}" -ge 1 ]] && kubectl -n "$namespace" logs crash-report -c report --previous 2>/dev/null | grep -q crash-token=; then previous_instance_ready=1; break; fi
  sleep 2
done
test "$previous_instance_ready" -eq 1
kubectl -n "$namespace" wait --for=condition=Ready pod/crash-report --timeout=120s
