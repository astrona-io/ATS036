#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-010-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-010-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace=starfleet-036-010-01-02
suspect_pod="$(kubectl -n "$namespace" get configmap shell-alert -o jsonpath='{.data.pod}')"

# Capture evidence from inside the running Pod before any change.
kubectl -n "$namespace" debug "$suspect_pod" --image=docker.io/library/busybox:1.37.0 \
  --target=probe --container=evidence -- sh -c 'ps; ls -l /proc/1/root/tmp'

# Quarantine: remove the labels that the Deployment and the Service select.
kubectl -n "$namespace" label pod "$suspect_pod" app- release- quarantine=true
kubectl -n "$namespace" rollout status deployment/probe --timeout=120s
