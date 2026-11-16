#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-01-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-01-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-036-020-01-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-036-020-01-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-036-020-01-01 wait --for=condition=Ready pod/drifter --timeout=120s

kubectl apply -f "$lab_directory/bootstrap/manifests/fault.yaml"
previous_instance_ready=0
for attempt in $(seq 1 60); do
  restart_count="$(kubectl -n starfleet-036-020-01-01 get pod crash-report -o jsonpath='{.status.containerStatuses[0].restartCount}')"
  if [[ "${restart_count:-0}" -ge 1 ]] && kubectl -n starfleet-036-020-01-01 logs crash-report -c report --previous | grep -q application-started; then previous_instance_ready=1; break; fi
  sleep 2
done
test "$previous_instance_ready" -eq 1
