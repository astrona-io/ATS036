#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-010-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-010-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

# The audit ID, Pod name, node and container ID are created at run time, so a
# fixed YAML file cannot hold them. The script reads them from the audit log
# and the Pod status, then applies ConfigMap exec-correlation.
python3 "$solution_directory/record-correlation.py"
