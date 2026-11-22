#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-02-02}"
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
echo "=== CAPTURE l1-count"
kubectl -n starfleet-036-020-02-02 logs login-service | grep -c "login failed"
echo "=== CAPTURE l1-full-log"
kubectl -n starfleet-036-020-02-02 logs login-service
echo "=== CAPTURE l1-by-source"
kubectl -n starfleet-036-020-02-02 logs login-service | grep "login failed" | sort | uniq -c
echo "=== CAPTURE l1-source-lines"
kubectl -n starfleet-036-020-02-02 logs login-service --timestamps | grep "src=10.0.0.23"
bash "$solution_directory/apply.real.sh" 2>&1
echo "=== CAPTURE l1-report"
kubectl -n starfleet-036-020-02-02 get configmap login-findings -o jsonpath='{.data}{"\n"}'

echo "=== CAPTURE end"
exit 1
