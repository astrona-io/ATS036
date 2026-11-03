#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-036-capstone-020" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s

kubectl apply -f "$lab_directory/bootstrap/manifests/evidence.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/suspect-pod --timeout=120s
kubectl -n starfleet wait --for=condition=Ready pod/login-service --timeout=120s
kubectl -n starfleet wait --for=condition=Ready pod/data-client --timeout=120s

restart_ready=0
for attempt in $(seq 1 60); do
  restart_count="$(kubectl -n starfleet get pod crash-report -o jsonpath='{.status.containerStatuses[0].restartCount}')"
  if [[ "${restart_count:-0}" -ge 1 ]]; then restart_ready=1; break; fi
  sleep 2
done
test "$restart_ready" -eq 1
