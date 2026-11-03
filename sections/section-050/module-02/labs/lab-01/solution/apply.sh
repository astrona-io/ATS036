#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-036-lab-050-02-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-036-lab-050-02-01-control-plane"
worker_name="astro-ats-036-lab-050-02-01-worker"
kubectl -n starfleet exec shuttle -- id
kubectl apply -f "$solution_directory/configmap-audit-exec.yaml"
