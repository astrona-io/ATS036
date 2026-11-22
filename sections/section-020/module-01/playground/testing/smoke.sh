#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here. The pages write `podman exec` for node commands; this script
# uses "$engine" instead, because CI runs kind on docker.
set -euo pipefail
playground=ats-036-playground-020-01
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-$playground}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-$playground}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"
worker_name="$cluster-worker"

# Write the code block that follows "Save this as `<file>`:" on a page into the
# work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save this as `' + re.escape(name) + r'`:\s*```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_file_from_page "$1" "$2"
  kubectl apply -f "$2"
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# While the kubelet restarts the container, kubectl can print "unable to
# retrieve container logs" for a moment. Retry the page command for a bounded time.
read_previous_log() {
  local output attempt
  for attempt in $(seq 1 20); do
    if output="$(kubectl -n starfleet logs crash-report -c report --previous "$@" 2>&1)" && [[ "$output" != *'unable to retrieve container logs'* ]]; then
      printf '%s\n' "$output"; return 0
    fi
    sleep 3
  done
  printf '%s\n' "$output"
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

timestamp='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z'

# Guided Practice: Diagnose A Previous Container Exit
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pod_json="$(kubectl -n starfleet get pod crash-report -o json)"
last_exit="$(printf '%s' "$pod_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["status"]["containerStatuses"][0]["lastState"]["terminated"]["exitCode"])')"
restarts="$(printf '%s' "$pod_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["status"]["containerStatuses"][0]["restartCount"])')"
expect_match 'guide: crash-report has restarted at least once' "$restarts" '^[1-9][0-9]*$'
expect_equal 'guide: the last terminated instance exited with 12' "$last_exit" 12
previous_log="$(read_previous_log --timestamps)"
printf '%s\n' "$previous_log"
expect_match 'guide: the previous log has the start marker with a timestamp' "$previous_log" "^$timestamp application-started\$"
expect 'guide: apply creates crash-diagnosis' "$(save_from_page "$page" configmap-crash-diagnosis.yaml)" 'configmap/crash-diagnosis created'
expect_equal 'guide: the diagnosis exitCode matches the last terminated instance' "$(kubectl -n starfleet get configmap crash-diagnosis -o jsonpath='{.data.exitCode}')" "$last_exit"
expect_equal 'guide: the previous log contains the marker' "$(read_previous_log)" application-started

# Security Signals By Layer
page=course-01-security-signals-by-layer.md
expect_equal 'the context is kind-astro-ats-036-playground-020-01' "$(kubectl config current-context)" "$context"
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_equal 'both nodes are Ready' "$(printf '%s\n' "$nodes" | grep -c ' Ready ' || true)" 2
all_pods="$(kubectl get pods -A -o wide)"
printf '%s\n' "$all_pods"
expect_match 'the listing names the node of crash-report' "$all_pods" "^starfleet +crash-report .* $worker_name "
events="$(kubectl get events -A --sort-by=.lastTimestamp)"
printf '%s\n' "$events"
expect 'events exist for the probe Pods' "$events" 'pod/probe-'
expect 'events exist for crash-report' "$events" 'pod/crash-report'
crash_uid="$(kubectl -n starfleet get pod crash-report -o jsonpath='{.metadata.uid}')"
pod_directories="$("$engine" exec "$worker_name" ls /var/log/pods)"
printf '%s\n' "$pod_directories"
expect_match 'the worker has a log directory starfleet_crash-report_<uid>' "$pod_directories" "^starfleet_crash-report_$crash_uid\$"
kubelet_log="$("$engine" exec "$worker_name" journalctl -u kubelet --no-pager -n 5)"
printf '%s\n' "$kubelet_log"
expect_match 'the journal prints kubelet log lines' "$kubelet_log" 'kubelet\[[0-9]+\]:'

# Workload Logs, Restarts And Exit Evidence
page=course-02-workload-logs-restarts-and-exit-evidence.md
crash_pod="$(kubectl -n starfleet get pod crash-report)"
printf '%s\n' "$crash_pod"
expect_match 'RESTARTS is at least 1 and STATUS is Error, CrashLoopBackOff or Running' "$crash_pod" '^crash-report +[01]/1 +(Error|CrashLoopBackOff|Running) +[1-9][0-9]* '
expect_equal 'the last exit code and reason are 12 Error' "$(kubectl -n starfleet get pod crash-report -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{" "}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}')" '12 Error'
previous_log="$(read_previous_log --timestamps)"
printf '%s\n' "$previous_log"
expect_match 'the previous log is application-started after a timestamp' "$previous_log" "^$timestamp application-started\$"
probe_logs="$(kubectl -n starfleet logs -l app=probe --prefix --tail=3)"
printf '%s\n' "$probe_logs"
expect_match 'the probe Pods have log lines' "$probe_logs" '.'
expect_equal 'every line starts with [pod/probe-<hash>/probe]' "$(printf '%s\n' "$probe_logs" | grep -cvE '^\[pod/probe-[a-z0-9-]+/probe\] ' || true)" 0

# Network Traffic, Application Logs And Evidence Gaps
page=course-03-network-traffic-application-logs-and-evidence-gaps.md
shuttle_answer="$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe.starfleet.svc)"
printf '%s\n' "$shuttle_answer"
expect_match 'shuttle gets version=v1 host=... greeting=hello' "$shuttle_answer" '^version=v1 host=probe-.* greeting=hello$'
drifter_answer="$(kubectl -n outpost exec drifter -- wget -qO- -T 3 http://probe.starfleet.svc)"
printf '%s\n' "$drifter_answer"
expect_match 'drifter gets the same answer from another namespace' "$drifter_answer" '^version=v1 host=probe-.* greeting=hello$'
expect 'no NetworkPolicy exists' "$(kubectl get networkpolicy -A 2>&1)" 'No resources found'
request_logs="$(kubectl -n starfleet logs -l app=probe --prefix --tail=6)"
printf '%s\n' "$request_logs"
expect 'the log has readiness probe requests' "$request_logs" '"GET /ready HTTP/1.1" 200'
all_pods="$(kubectl get pods -A -o wide)"
printf '%s\n' "$all_pods"
shuttle_ip="$(printf '%s\n' "$all_pods" | awk '$1 == "starfleet" && $2 == "shuttle" {print $7}')"
drifter_ip="$(printf '%s\n' "$all_pods" | awk '$1 == "outpost" && $2 == "drifter" {print $7}')"
expect_match 'the request from shuttle carries the IP of shuttle' "$request_logs" "\] ${shuttle_ip//./\\.} - - .*\"GET / HTTP/1.1\" 200"
expect_match 'the request from drifter carries the IP of drifter' "$request_logs" "\] ${drifter_ip//./\\.} - - .*\"GET / HTTP/1.1\" 200"

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
