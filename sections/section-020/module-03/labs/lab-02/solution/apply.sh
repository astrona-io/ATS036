#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-03-02}"
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
echo "=== CAPTURE l2-pod-columns"
kubectl -n starfleet-036-020-03-02 get pods -o custom-columns='NAME:.metadata.name,SECRETENV:.spec.containers[*].env[*].valueFrom.secretKeyRef.name,SECRETVOL:.spec.volumes[*].secret.secretName'
echo "=== CAPTURE l2-deployment-columns"
kubectl -n starfleet-036-020-03-02 get deployments -o custom-columns='NAME:.metadata.name,SECRETENV:.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name,SECRETVOL:.spec.template.spec.volumes[*].secret.secretName'
echo "=== CAPTURE l2-printenv-before"
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- printenv DB_PASSWORD 2>&1
bash "$solution_directory/apply.real.sh" 2>&1
echo "=== CAPTURE l2-report"
kubectl -n starfleet-036-020-03-02 get configmap secret-exposure -o jsonpath='{.data}{"\n"}'
echo "=== CAPTURE l2-rollout"
kubectl -n starfleet-036-020-03-02 rollout status deployment/billing --timeout=120s 2>&1
sleep 8
echo "=== CAPTURE l2-ls"
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- ls -lL /etc/db 2>&1
echo "=== CAPTURE l2-cat"
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- cat /etc/db/password; echo
echo "=== CAPTURE l2-printenv-after"
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- printenv DB_PASSWORD 2>&1; echo "exit code $?"

echo "=== CAPTURE end"
exit 1
