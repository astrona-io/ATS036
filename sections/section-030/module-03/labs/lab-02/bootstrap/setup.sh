#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace=starfleet-036-030-03-02
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl -n "$namespace" rollout status deployment/cruncher --timeout=120s
kubectl -n "$namespace" wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-036-030-03-02 wait --for=condition=Ready pod/drifter --timeout=120s

# The memory-hog container writes more memory than its limit allows, so the
# kernel kills it and the kubelet records OOMKilled as the reason.
oom_recorded=0
for attempt in $(seq 1 90); do
  reason="$(kubectl -n "$namespace" get pod memory-hog -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')"
  if [[ "$reason" == OOMKilled ]]; then oom_recorded=1; break; fi
  sleep 2
done
test "$oom_recorded" -eq 1
