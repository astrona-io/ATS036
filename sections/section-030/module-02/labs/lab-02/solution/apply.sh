#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace="starfleet-036-030-02-02"

kubectl apply -f "$solution_directory/configmap-persistence-finding.yaml"
# Suspend first, so the CronJob controller starts no new Job while the
# running ones are removed.
kubectl -n "$namespace" patch cronjob node-report --type=merge -p '{"spec":{"suspend":true}}'
pods_gone=0
for attempt in $(seq 1 45); do
  kubectl -n "$namespace" delete jobs -l app=node-report --ignore-not-found --wait=false
  if [[ -z "$(kubectl -n "$namespace" get pods -l app=node-report -o name)" ]]; then pods_gone=1; break; fi
  sleep 2
done
test "$pods_gone" -eq 1
