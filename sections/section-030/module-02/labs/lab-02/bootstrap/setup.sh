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
namespace="starfleet-036-030-02-02"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# The CronJob controller starts the first node-report Job at the next full
# minute. Wait for its Pod for a bounded time, so the learner meets a running Job.
job_started=0
for attempt in $(seq 1 60); do
  if [[ -n "$(kubectl -n "$namespace" get pods -l app=node-report -o name)" ]]; then job_started=1; break; fi
  sleep 2
done
test "$job_started" -eq 1
kubectl -n "$namespace" wait --for=condition=Ready pod -l app=node-report --timeout=120s
