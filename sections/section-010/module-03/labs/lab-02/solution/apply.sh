#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-010-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-010-03-02}"
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
ns=starfleet-036-010-03-02
echo "=== CAPTURE l1-probe-pods"
kubectl -n $ns get pods -l app=probe -o wide
cat > /tmp/exec-report.py <<'PY'
import json
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("subresource") != "exec":
        continue
    print(
        event.get("auditID"),
        event.get("stage"),
        reference.get("name"),
        event.get("requestURI"),
    )
PY
echo "=== CAPTURE l1-exec-report"
"$engine" exec "$cluster-control-plane" cat /var/log/training-audit/audit.jsonl | python3 /tmp/exec-report.py
python3 "$solution_directory/record-correlation.py" 2>&1
pod_name=$(kubectl -n $ns get configmap exec-correlation -o jsonpath='{.data.podName}')
echo "=== CAPTURE l1-node-name"
kubectl -n $ns get pod "$pod_name" -o jsonpath='{.spec.nodeName}{"\n"}'
echo "=== CAPTURE l1-container-ids"
kubectl -n $ns get pod "$pod_name" -o jsonpath='{range .status.containerStatuses[*]}{.name}{" "}{.containerID}{"\n"}{end}'
echo "=== CAPTURE l1-crictl-ps"
container_id=$(kubectl -n $ns get pod "$pod_name" -o jsonpath='{.status.containerStatuses[?(@.name=="probe")].containerID}')
pod_node=$(kubectl -n $ns get pod "$pod_name" -o jsonpath='{.spec.nodeName}')
"$engine" exec "$pod_node" crictl ps --id "${container_id#containerd://}"
echo "=== CAPTURE l1-configmap"
kubectl -n $ns get configmap exec-correlation -o yaml

echo "=== CAPTURE end"
exit 1
