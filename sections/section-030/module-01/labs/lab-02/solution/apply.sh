#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace="starfleet-036-030-01-02"

kubectl -n "$namespace" label pod threat-client incident=quarantine --overwrite
kubectl apply -f "$solution_directory/networkpolicy-quarantine.yaml"
kubectl -n "$namespace" delete secret threat-reader-token --ignore-not-found
kubectl -n "$namespace" delete rolebinding threat-reader-secrets --ignore-not-found
