#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-lab-050-02-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-lab-050-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="${cluster}-control-plane"

# Task 2: copy the corrected policy to the control plane node.
"$engine" cp "$solution_directory/training-audit-policy.json" "$node_name:/etc/kubernetes/training-audit-policy.json"

# Task 3: restart the API server. The kubelet stops the static Pod when its
# manifest leaves the manifests directory and starts it again when it returns.
"$engine" exec "$node_name" mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/kube-apiserver.yaml
stopped=0
for attempt in $(seq 1 30); do
  if [[ -z "$("$engine" exec "$node_name" crictl ps --name kube-apiserver -q)" ]]; then stopped=1; break; fi
  sleep 2
done
"$engine" exec "$node_name" mv /etc/kubernetes/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
test "$stopped" -eq 1
api_ready=0
for attempt in $(seq 1 40); do
  if kubectl --request-timeout=3s get --raw=/readyz >/dev/null 2>&1; then api_ready=1; break; fi
  sleep 3
done
test "$api_ready" -eq 1

# Task 4: send one exec request and one port-forward session.
kubectl -n starfleet-036-050-02-02 exec shuttle -- id
forward_output="$(mktemp)"
kubectl -n starfleet-036-050-02-02 port-forward service/probe 18080:80 >"$forward_output" 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true; rm -f "$forward_output"' EXIT
forwarding=0
for attempt in $(seq 1 20); do
  if grep -q 'Forwarding from' "$forward_output"; then forwarding=1; break; fi
  sleep 1
done
test "$forwarding" -eq 1
python3 -c 'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:18080/", timeout=5).read().decode().strip())'
kill "$forward_pid"
wait "$forward_pid" 2>/dev/null || true
