#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-010-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-010-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace=starfleet-036-010-01-02
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl -n "$namespace" wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-036-010-01-02 wait --for=condition=Ready pod/drifter --timeout=120s

# The alert names the first probe Pod by name. A shell in that Pod writes a
# file, which is the behavior the alert reports.
suspect_pod="$(kubectl -n "$namespace" get pods -l app=probe,release=probe --sort-by=.metadata.name -o jsonpath='{.items[0].metadata.name}')"
suspect_uid="$(kubectl -n "$namespace" get pod "$suspect_pod" -o jsonpath='{.metadata.uid}')"
kubectl -n "$namespace" exec "$suspect_pod" -c probe -- sh -c 'echo staged > /tmp/dropped-tool'
kubectl -n "$namespace" create configmap shell-alert \
  --from-literal=pod="$suspect_pod" \
  --from-literal=uid="$suspect_uid" \
  --from-literal=container=probe \
  --from-literal=rule="Shell started in probe container"
