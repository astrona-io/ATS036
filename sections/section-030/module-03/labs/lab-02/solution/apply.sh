#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
namespace=starfleet-036-030-03-02
kubectl apply -f "$solution_directory/configmap-impact-report.yaml"
kubectl -n "$namespace" set resources deployment/cruncher -c worker --requests=cpu=10m,memory=16Mi --limits=cpu=200m,memory=64Mi
kubectl -n "$namespace" rollout status deployment/cruncher --timeout=120s
kubectl apply -f "$solution_directory/limitrange-container-limits.yaml"
