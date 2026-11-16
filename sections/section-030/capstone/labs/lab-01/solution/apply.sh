#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-capstone-030}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-capstone-030}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="${cluster}-control-plane"
worker_name="${cluster}-worker"

python3 "$solution_directory/record-incident.py"
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit --ignore-not-found
kubectl -n outpost label pod intruder incident=quarantine --overwrite
