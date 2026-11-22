#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl label namespace starfleet-036-040-01-02 immutability=enforced --overwrite
kubectl apply -f "$solution_directory/validatingadmissionpolicy-require-read-only-root.yaml"
kubectl apply -f "$solution_directory/validatingadmissionpolicybinding-require-read-only-root.yaml"
