#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-030-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-playground-030-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="${cluster}-control-plane"
worker_name="${cluster}-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
python3 "$lab_directory/bootstrap/enable-audit.py"
api_ready=0
for attempt in $(seq 1 80); do
  if "$engine" exec "$node_name" test -f /var/log/training-audit/audit.jsonl && kubectl --request-timeout=3s get --raw=/readyz >/dev/null 2>&1; then api_ready=1; break; fi
  sleep 3
done
test "$api_ready" -eq 1

kubectl -n starfleet wait --for=condition=Ready pod/threat-client --timeout=180s
kubectl -n starfleet exec threat-client -- python /app/request.py
