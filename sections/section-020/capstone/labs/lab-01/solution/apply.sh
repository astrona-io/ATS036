#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-capstone-020}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-capstone-020}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/configmap-threat-register.yaml"
kubectl -n starfleet delete rolebinding reporter-secrets --ignore-not-found

