#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-020-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-020-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-036-020-02-02 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-036-020-02-02 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-036-020-02-02 wait --for=condition=Ready pod/drifter --timeout=120s

kubectl apply -f "$lab_directory/bootstrap/manifests/evidence.yaml"
kubectl -n starfleet-036-020-02-02 wait --for=condition=Ready pod/login-service --timeout=120s

# The container writes its whole log before it reports ready. Wait, with a
# limit, until the last line has reached the container log as well.
for attempt in $(seq 1 30); do
  log_text="$(kubectl -n starfleet-036-020-02-02 logs login-service --request-timeout=20s 2>/dev/null || true)"
  if grep -qx "service ready" <<<"$log_text"; then
    exit 0
  fi
  sleep 2
done
printf 'The login-service log did not reach its last line within one minute\n' >&2
exit 1
