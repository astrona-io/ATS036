#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-02-02}"
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
ns=starfleet-036-030-02-02
echo "=== CAPTURE lab2-objects-before"
kubectl -n $ns get cronjobs,jobs,pods
echo "=== CAPTURE lab2-job-owners"
kubectl -n $ns get jobs -o custom-columns=NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name
echo "=== CAPTURE lab2-pod-owners"
kubectl -n $ns get pods -l app=node-report -o custom-columns=NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name
echo "=== CAPTURE lab2-template-before"
kubectl -n $ns get cronjob node-report -o jsonpath='{.spec.suspend}{" "}{.spec.jobTemplate.spec.template.spec.serviceAccountName}{" "}{.spec.jobTemplate.spec.template.spec.hostPID}{"\n"}'
echo "=== CAPTURE lab2-hostpid-ps"
report_pod="$(kubectl -n $ns get pods -l app=node-report -o jsonpath='{.items[0].metadata.name}')"; kubectl -n $ns exec "$report_pod" -- ps -o pid,user,comm 2>&1
bash "$solution_directory/apply.real.sh" 2>&1
echo "=== CAPTURE lab2-objects-after"
kubectl -n $ns get cronjobs,jobs,pods
sleep 65
echo "=== CAPTURE lab2-objects-next-minute"
kubectl -n $ns get cronjobs,jobs,pods

echo "=== CAPTURE end"
exit 1
