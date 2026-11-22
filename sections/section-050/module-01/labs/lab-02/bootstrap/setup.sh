#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-050-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-050-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="${cluster}-control-plane"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
python3 "$lab_directory/bootstrap/enable-audit.py"
api_ready=0
for attempt in $(seq 1 80); do
  if "$engine" exec "$node_name" test -f /var/log/training-audit/audit.jsonl && kubectl --request-timeout=3s get --raw=/readyz >/dev/null 2>&1; then api_ready=1; break; fi
  sleep 3
done
test "$api_ready" -eq 1
# Seed the log with two other Secret reads: an allowed read by the cluster
# administrator and a denied read as the default ServiceAccount of outpost.
# Neither one is the record the task asks for.
kubectl -n starfleet-036-050-01-02 get secret navigation-key -o name >/dev/null
kubectl -n starfleet-036-050-01-02 get secret navigation-key --as=system:serviceaccount:outpost-036-050-01-02:default >/dev/null 2>&1 || true
