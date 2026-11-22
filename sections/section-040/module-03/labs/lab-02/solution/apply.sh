#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-040-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-040-03-02}"
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
echo "=== CAPTURE find-hostpath"
kubectl -n starfleet-036-040-03-02 get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.volumes[*].hostPath.path}{"\n"}{end}'
echo "=== CAPTURE candidate-mounts"
kubectl -n starfleet-036-040-03-02 get deployment collector relay -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].volumeMounts}{"\n"}{end}'
echo "=== CAPTURE write-before-fix"
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- sh -c 'echo written-by-pod > /host-data/write-test && cat /host-data/write-test' 2>&1
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- rm /host-data/write-test 2>&1
echo "=== CAPTURE finding"
kubectl apply -f "$solution_directory/configmap-hostpath-finding.yaml" 2>&1
kubectl -n starfleet-036-040-03-02 get configmap hostpath-finding -o jsonpath='{.data}{"\n"}'
echo "=== CAPTURE rollout"
kubectl apply -f "$solution_directory/deployment-collector.yaml" 2>&1
kubectl -n starfleet-036-040-03-02 rollout status deployment/collector --timeout=180s 2>&1
sleep 5
echo "=== CAPTURE read-after-fix"
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- cat /host-data/approved.txt 2>&1
echo "=== CAPTURE write-after-fix"
kubectl -n starfleet-036-040-03-02 exec deploy/collector -- sh -c 'echo changed > /host-data/write-test' 2>&1; echo "exit code $?"

echo "=== CAPTURE end"
exit 1
