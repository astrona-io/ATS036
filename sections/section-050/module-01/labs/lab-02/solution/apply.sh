#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-050-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-050-01-02}"
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
node_name="${cluster}-control-plane"
echo "=== CAPTURE l1-policy"
"$engine" exec "$node_name" cat /etc/kubernetes/training-audit-policy.json
echo "=== CAPTURE l1-denied-read"
kubectl -n starfleet-036-050-01-02 get secret navigation-key --as=system:serviceaccount:outpost-036-050-01-02:drifter 2>&1; echo "exit: $?"
sleep 4
echo "=== CAPTURE l1-find-record"
"$engine" exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 "$solution_directory/find-denied-read.py"
bash "$solution_directory/apply.real.sh" 2>&1
audit_id=$(kubectl -n starfleet-036-050-01-02 get configmap denied-read-report -o jsonpath='{.data.auditID}')
echo "=== CAPTURE l1-full-record"
"$engine" exec "$node_name" grep -F "$audit_id" /var/log/training-audit/audit.jsonl | python3 -m json.tool
echo "=== CAPTURE l1-report"
kubectl -n starfleet-036-050-01-02 get configmap denied-read-report -o jsonpath='{.data}{"\n"}'

echo "=== CAPTURE end"
exit 1
