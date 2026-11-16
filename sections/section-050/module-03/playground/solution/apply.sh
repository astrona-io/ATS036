#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-050-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-playground-050-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="${cluster}-control-plane"
worker_name="${cluster}-worker"
report_file="$(mktemp)"
python3 "$solution_directory/record-retention.py" "$node_name" > "$report_file"
kubectl apply -f "$report_file"
rm -f "$report_file"
