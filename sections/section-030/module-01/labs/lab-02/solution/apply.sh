#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-01-02}"
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
ns=starfleet-036-030-01-02
echo "=== CAPTURE lab1-pods-before"
kubectl -n $ns get pods --show-labels
echo "=== CAPTURE lab1-ticket-uid"
kubectl -n $ns get configmap incident-ticket -o jsonpath='{.data.podUID}{"\n"}'; kubectl -n $ns get pod threat-client -o jsonpath='{.metadata.uid}{"\n"}'
echo "=== CAPTURE lab1-token-secrets-before"
kubectl -n $ns get secrets --field-selector type=kubernetes.io/service-account-token -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.metadata.annotations.kubernetes\\.io/service-account\\.name
echo "=== CAPTURE lab1-rbac-before"
kubectl -n $ns get rolebindings -o wide; kubectl -n $ns auth can-i get secrets --as=system:serviceaccount:$ns:threat-reader || true
echo "=== CAPTURE lab1-traffic-before"
kubectl -n $ns exec threat-client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local 2>&1 | head -8; echo "exit: ${PIPESTATUS[0]}"
bash "$solution_directory/apply.real.sh" 2>&1
echo "=== CAPTURE lab1-quarantine-after"
kubectl -n $ns get pod threat-client -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,PHASE:.status.phase,INCIDENT:.metadata.labels.incident; kubectl -n $ns get networkpolicy quarantine -o yaml
echo "=== CAPTURE lab1-traffic-after"
sleep 5
kubectl -n $ns exec threat-client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local 2>&1 | head -8; echo "exit: ${PIPESTATUS[0]}"
probe_pod=$(kubectl -n $ns get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')
echo "--- same lookup from $probe_pod"
kubectl -n $ns exec "$probe_pod" -- nslookup -timeout=3 kubernetes.default.svc.cluster.local 2>&1 | head -8; echo "exit: ${PIPESTATUS[0]}"
echo "=== CAPTURE lab1-access-after"
for v in get list; do kubectl -n $ns auth can-i $v secrets --as=system:serviceaccount:$ns:threat-reader || true; done; kubectl -n $ns auth can-i get secrets --as=system:serviceaccount:$ns:probe-reader || true; kubectl -n $ns get secrets --field-selector type=kubernetes.io/service-account-token 2>&1

echo "=== CAPTURE end"
exit 1
