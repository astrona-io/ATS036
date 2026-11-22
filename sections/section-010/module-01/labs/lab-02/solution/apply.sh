#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-010-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-010-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
engine="${engine:-${ASTRONA_CONTAINER_ENGINE:-podman}}"
cluster="${cluster:-${ASTRONA_KIND_CLUSTER:-}}"
set +e
exec 2>&1
n=starfleet-036-010-01-02
echo "=== CAPTURE alert"
kubectl -n starfleet-036-010-01-02 get configmap shell-alert -o jsonpath='{.data}{"\n"}'
suspect_pod="$(kubectl -n starfleet-036-010-01-02 get configmap shell-alert -o jsonpath='{.data.pod}')"
kubectl -n starfleet-036-010-01-02 get pods -L app,release
echo "=== CAPTURE debug"
kubectl -n starfleet-036-010-01-02 debug "$suspect_pod" --image=docker.io/library/busybox:1.37.0 --target=probe --container=evidence -- sh -c 'ps; ls -l /proc/1/root/tmp' 2>&1
sleep 8
echo "=== CAPTURE evidence-log"
kubectl -n starfleet-036-010-01-02 logs "$suspect_pod" -c evidence 2>&1
echo "=== CAPTURE label"
kubectl -n starfleet-036-010-01-02 label pod "$suspect_pod" app- release- quarantine=true 2>&1
kubectl -n starfleet-036-010-01-02 rollout status deployment/probe --timeout=120s 2>&1
sleep 5
echo "=== CAPTURE check"
kubectl -n starfleet-036-010-01-02 get pods -L app,release,quarantine -o wide 2>&1
kubectl -n starfleet-036-010-01-02 get endpointslices -l kubernetes.io/service-name=probe 2>&1

echo "=== CAPTURE end"
exit 1
