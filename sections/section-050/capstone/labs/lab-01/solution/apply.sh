#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-036-capstone-050" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-036-capstone-050-control-plane"
worker_name="astro-ats-036-capstone-050-worker"
kubectl -n starfleet get secret audit-token -o name
kubectl -n starfleet get secret audit-token --as=system:serviceaccount:outpost:default || true
kubectl -n starfleet exec shuttle -- id
report_file="$(mktemp)"
python3 "$solution_directory/record-investigation.py" "$node_name" > "$report_file"
kubectl apply -f "$report_file"
rm -f "$report_file"
