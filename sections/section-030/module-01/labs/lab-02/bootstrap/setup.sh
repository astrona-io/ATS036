#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-030-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-030-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-036-030-01-02"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl -n "$namespace" wait --for=condition=Ready pod/threat-client --timeout=180s
# The token controller in kube-controller-manager fills the token Secret
# shortly after it is created. Wait for it for a bounded time.
token_ready=0
for attempt in $(seq 1 30); do
  if [[ -n "$(kubectl -n "$namespace" get secret threat-reader-token -o jsonpath='{.data.token}')" ]]; then token_ready=1; break; fi
  sleep 2
done
test "$token_ready" -eq 1
# Record the UID of the Pod under investigation, so the grader can tell the
# original Pod from a recreated one with the same name.
pod_uid="$(kubectl -n "$namespace" get pod threat-client -o jsonpath='{.metadata.uid}')"
test -n "$pod_uid"
kubectl -n "$namespace" create configmap incident-ticket \
  --from-literal=pod=threat-client \
  --from-literal=podUID="$pod_uid" \
  --from-literal=serviceAccount=threat-reader \
  --dry-run=client -o yaml | kubectl apply -f -
