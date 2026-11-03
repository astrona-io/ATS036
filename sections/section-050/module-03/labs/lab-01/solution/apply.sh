#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-036-lab-050-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-036-lab-050-03-01-control-plane"
worker_name="astro-ats-036-lab-050-03-01-worker"
report_file="$(mktemp)"
python3 "$solution_directory/record-retention.py" "$node_name" > "$report_file"
kubectl apply -f "$report_file"
rm -f "$report_file"
