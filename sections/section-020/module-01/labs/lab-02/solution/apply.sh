#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-01-02}"
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
ns=starfleet-036-020-01-02
pod_node=$(kubectl -n $ns get pod crash-report -o jsonpath='{.spec.nodeName}')
pod_uid=$(kubectl -n $ns get pod crash-report -o jsonpath='{.metadata.uid}')
log_directory="/var/log/pods/${ns}_crash-report_${pod_uid}"
echo "=== CAPTURE l2-pod-wide"
kubectl -n $ns get pod crash-report -o wide
echo "=== CAPTURE l2-node-uid"
echo "$pod_node $pod_uid"
echo "=== CAPTURE l2-pods-directory"
"$engine" exec "$pod_node" ls /var/log/pods
echo "=== CAPTURE l2-report-files"
"$engine" exec "$pod_node" ls -l "$log_directory/report"
echo "=== CAPTURE l2-previous-file"
"$engine" exec "$pod_node" cat "$log_directory/report/0.log"
echo "=== CAPTURE l2-container-links"
"$engine" exec "$pod_node" ls -l /var/log/containers | grep crash-report
bash "$solution_directory/apply.real.sh" 2>&1
echo "=== CAPTURE l2-configmap"
kubectl -n $ns get configmap node-log-evidence -o yaml

echo "=== CAPTURE end"
exit 1
