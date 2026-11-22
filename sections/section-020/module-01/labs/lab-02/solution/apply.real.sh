#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace="starfleet-036-020-01-02"

# The node, Pod UID and token are created at run time, so a fixed YAML file
# cannot hold them. Read them from the Pod and from the node, then apply
# ConfigMap node-log-evidence.
pod_node="$(kubectl -n "$namespace" get pod crash-report -o jsonpath='{.spec.nodeName}')"
case "$pod_node" in
  "$cluster-control-plane"|"$cluster-worker") ;;
  *) printf 'Pod crash-report runs on a node outside this lab: %s\n' "$pod_node" >&2; exit 1 ;;
esac
pod_uid="$(kubectl -n "$namespace" get pod crash-report -o jsonpath='{.metadata.uid}')"
restart_count="$(kubectl -n "$namespace" get pod crash-report -o jsonpath='{.status.containerStatuses[?(@.name=="report")].restartCount}')"
log_directory="/var/log/pods/${namespace}_crash-report_${pod_uid}"
log_files="$("$engine" exec "$pod_node" ls "$log_directory/report" | sort | paste -sd, -)"
crash_token="$("$engine" exec "$pod_node" cat "$log_directory/report/$((restart_count - 1)).log" | sed -n 's/.*crash-token=//p' | head -n 1)"
test -n "$crash_token"

kubectl -n "$namespace" create configmap node-log-evidence \
  --from-literal=nodeName="$pod_node" \
  --from-literal=podUID="$pod_uid" \
  --from-literal=logDirectory="$log_directory" \
  --from-literal=logFiles="$log_files" \
  --from-literal=crashToken="$crash_token" \
  --dry-run=client -o yaml | kubectl apply -f -
