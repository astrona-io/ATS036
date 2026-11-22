#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/configmap-privilege-finding.yaml"
kubectl label namespace starfleet-036-040-02-02 pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=latest --overwrite
kubectl apply -f "$solution_directory/deployment-telemetry-agent.yaml"
kubectl -n starfleet-036-040-02-02 rollout status deployment/telemetry-agent --timeout=180s
kubectl -n starfleet-036-040-02-02 delete pod node-inspector --ignore-not-found --wait=true --timeout=60s
