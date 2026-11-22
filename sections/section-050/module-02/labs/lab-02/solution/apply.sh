#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-050-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-050-02-02}"
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
ns=starfleet-036-050-02-02
echo "=== CAPTURE l2-exec-before"
kubectl -n $ns exec shuttle -- id; sleep 3; "$engine" exec "$node_name" grep -c '"subresource":"exec"' /var/log/training-audit/audit.jsonl
echo "=== CAPTURE l2-policy-before"
"$engine" exec "$node_name" cat /etc/kubernetes/training-audit-policy.json
echo "=== CAPTURE l2-policy-after"
"$engine" cp "$solution_directory/training-audit-policy.json" "$node_name":/etc/kubernetes/training-audit-policy.json; "$engine" exec "$node_name" head -n 20 /etc/kubernetes/training-audit-policy.json
echo "=== CAPTURE l2-apiserver-stopped"
"$engine" exec "$node_name" mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/kube-apiserver.yaml
for attempt in $(seq 1 30); do
  if [[ -z "$("$engine" exec "$node_name" crictl ps --name kube-apiserver -q)" ]]; then break; fi
  sleep 2
done
"$engine" exec "$node_name" crictl ps --name kube-apiserver
echo "=== CAPTURE l2-apiserver-ready"
"$engine" exec "$node_name" mv /etc/kubernetes/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
for attempt in $(seq 1 40); do kubectl --request-timeout=3s get --raw=/readyz 2>&1 && break; sleep 3; done
echo
echo "=== CAPTURE l2-requests-after"
bash "$solution_directory/apply.real.sh" 2>&1
sleep 3
echo "=== CAPTURE l2-report-after"
"$engine" exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 "$solution_directory/audit-pod-access.py"

echo "=== CAPTURE end"
exit 1
