#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-050-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-050-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="${cluster}-control-plane"
service_account="system:serviceaccount:outpost-036-050-01-02:drifter"

# Task 1: send the read as the ServiceAccount. The API server must deny it.
error_output="$(mktemp)"
trap 'rm -f "$error_output"' EXIT
if kubectl -n starfleet-036-050-01-02 get secret navigation-key --as="$service_account" >/dev/null 2>"$error_output"; then
  printf 'The impersonated read was allowed; it must be denied\n' >&2
  exit 1
fi
grep -q 'Forbidden' "$error_output"

# Task 2: find the ResponseComplete record of that request (bounded wait).
record=""
for attempt in $(seq 1 20); do
  record="$("$engine" exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 "$solution_directory/find-denied-read.py" | awk -v account="$service_account" '$3 == account && $5 == "navigation-key" && $6 == "403" {line=$0} END {print line}')"
  if [[ -n "$record" ]]; then break; fi
  sleep 2
done
test -n "$record"
audit_id="$(printf '%s\n' "$record" | awk '{print $1}')"
caller="$(printf '%s\n' "$record" | awk '{print $2}')"

# Task 3: record the evidence in the ConfigMap.
sed -e "s/<AUDIT_ID>/$audit_id/" -e "s/<USER>/$caller/" "$solution_directory/configmap-denied-read-report.yaml" | kubectl apply -f -
