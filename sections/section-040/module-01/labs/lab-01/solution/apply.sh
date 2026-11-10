#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-01-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-01-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster_name="astro-ats-036-lab-040-01-01"

kubectl apply -f "$solution_directory/pod-restricted-reader.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/restricted-reader --timeout=180s
