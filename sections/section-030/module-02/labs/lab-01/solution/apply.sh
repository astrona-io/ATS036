#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-02-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-02-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="${cluster}-control-plane"
worker_name="${cluster}-worker"

kubectl apply -f "$solution_directory/configmap-persistence-finding.yaml"
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit --ignore-not-found
