#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-capstone-040}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-capstone-040}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/deployment-probe.yaml"
kubectl apply -f "$solution_directory/validatingadmissionpolicy-require-read-only-root.yaml"
kubectl apply -f "$solution_directory/validatingadmissionpolicybinding-require-read-only-root.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
sleep 5
