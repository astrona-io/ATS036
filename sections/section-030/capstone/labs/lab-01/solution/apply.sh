#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-036-capstone-030" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-036-capstone-030-control-plane"
worker_name="astro-ats-036-capstone-030-worker"

python3 "$solution_directory/record-incident.py"
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit --ignore-not-found
kubectl -n outpost label pod intruder incident=quarantine --overwrite
