#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-050-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-036-050-03-02"
source "$lab_directory/bootstrap/helpers.sh"

run_on_node sed -i 's/^    token: incorrect-token$/    token: training-audit-token/' /etc/kubernetes/audit/webhook.yaml
run_on_node tee /etc/kubernetes/audit/policy.yaml >/dev/null <<'YAML'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  namespaces: ["starfleet-036-050-03-02"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: None
YAML

# kube-apiserver reads both files only when it starts: stop its container and
# the kubelet starts a new one from the same static Pod manifest.
old_container="$(run_on_node crictl ps --name '^kube-apiserver$' -q)"
run_on_node crictl stop "$old_container" >/dev/null
for attempt in $(seq 1 60); do
  new_container="$(run_on_node crictl ps --name '^kube-apiserver$' -q || true)"
  [[ -n "$new_container" && "$new_container" != "$old_container" ]] && break
  sleep 3
done
wait_for_api
