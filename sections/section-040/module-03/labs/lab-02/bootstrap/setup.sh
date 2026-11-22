#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
for deployment in collector relay beacon; do
  kubectl -n starfleet-036-040-03-02 rollout status "deployment/$deployment" --timeout=180s
done
kubectl -n outpost-036-040-03-02 wait --for=condition=Ready pod/drifter --timeout=120s
# The kubelet creates the node directory (DirectoryOrCreate). The writable
# collector mount stores the approved settings file that the fixed Pods must
# still read, and removes any grader file left by an earlier run.
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- sh -c 'printf "approved-settings-v1\n" > /host-data/approved.txt; rm -f /host-data/grader-write-test'
kubectl -n starfleet-036-040-03-02 exec deploy/relay -- cat /host-data/approved.txt
