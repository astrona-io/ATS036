#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages start with
# `export KUBECONFIG="$(astrona kubeconfig ...)"`; the runner has already done
# that, so the script skips it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-030-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages write their files to the current directory.
cd "$work_directory"

# Write the code block (YAML or Python) that follows "Save this as `<file>`"
# (or "as `<file>`") on a page.
save_yaml_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```(?:yaml|python)\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_absent() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" != *"$3"* ]] || { printf 'FAIL: %s\nunwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Print the full probe access log, as the page does, once it holds a request
# to / (the intruder sends one every five seconds), at most about 90 seconds.
probe_access_log() {
  local output='' attempt
  for attempt in $(seq 1 30); do
    output="$(kubectl -n starfleet logs -l app=probe --tail=-1)"
    [[ "$output" == *'"GET / HTTP'* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# Lateral movement and network evidence
page=course-01-lateral-movement-and-network-evidence.md
access_log="$(probe_access_log)"
recent="$(kubectl -n starfleet logs -l app=probe --prefix --tail=10)"
printf '%s\n' "$recent"
expect 'each line starts with the Pod name' "$(printf '%s\n' "$recent" | head -1)" '[pod/probe-'
expect 'each line has the client address, then the request' "$(printf '%s\n' "$recent" | head -1)" '"GET /'
counts="$(kubectl -n starfleet logs -l app=probe --tail=-1 | awk '{print $1}' | sort | uniq -c)"
printf '%s\n' "$counts"
checks=$((checks + 1))
printf 'check: %s\n' 'at least two client addresses appear'
[[ "$(printf '%s\n' "$counts" | grep -c .)" -ge 2 ]] || { printf 'FAIL: fewer than two client addresses\n' >&2; exit 1; }
readiness_ip="$(printf '%s\n' "$access_log" | awk '/"GET \/ready / {print $1}' | sort -u | head -1)"
expect 'the kubelet sends readiness requests to /ready' "$readiness_ip" .
# The address that sends the regular requests to /, as the page explains.
source_ip="$(printf '%s\n' "$access_log" | awk '/"GET \/ HTTP/ {print $1}' | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')"
expect 'one address sends requests to /' "$source_ip" .
pods="$(kubectl get pods -A -o wide)"
printf '%s\n' "$pods"
expect 'IP column is listed' "$(printf '%s\n' "$pods" | head -1)" IP
# The page has the reader replace <SOURCE_IP> with that address.
owner_line="$(kubectl get pods -A -o wide | grep -F "$source_ip")"
printf '%s\n' "$owner_line"
expect 'the address belongs to outpost/intruder' "$owner_line" outpost
expect 'the address belongs to the intruder Pod' "$owner_line" intruder
expect_equal 'the address matches only one Pod' "$(printf '%s\n' "$owner_line" | awk -v ip="$source_ip" '$7 == ip' | wc -l | tr -d ' ')" 1
expect_equal 'the kubelet address matches no Pod' "$(kubectl get pods -A -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | grep -cxF "$readiness_ip" || true)" 0

# Impact and resource abuse
page=course-02-impact-and-resource-abuse.md
limits="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory)"
printf '%s\n' "$limits"
expect_equal 'probe Pods have a memory limit but no CPU limit' "$(printf '%s\n' "$limits" | awk '$2 ~ /^probe-/ {print $3, $4}' | sort -u)" '<none> 128Mi'
expect_equal 'intruder has no limit at all' "$(printf '%s\n' "$limits" | awk '$2 == "intruder" {print $3, $4}')" '<none> <none>'
restarts="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason)"
printf '%s\n' "$restarts"
expect 'restart table has the LAST_REASON column' "$(printf '%s\n' "$restarts" | head -1)" LAST_REASON
expect_equal 'no container was OOMKilled' "$(printf '%s\n' "$restarts" | grep -c OOMKilled || true)" 0
# Any list of warnings, also an empty one, is a valid result on the page.
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp
allocated="$(kubectl describe node | grep -A 8 "Allocated resources")"
printf '%s\n' "$allocated"
expect 'node summary has the allocated resources section' "$allocated" 'Allocated resources:'
expect 'allocated resources compare requests and limits' "$allocated" 'Requests'
expect 'allocated resources list memory' "$allocated" memory
# The page says that kubectl top pods needs the Metrics Server, which the
# playground does not install, so the command fails.
status=0
top="$(kubectl top pods 2>&1)" || status=$?
printf '%s\n' "$top"
expect_equal 'kubectl top pods fails' "$status" 1
expect 'kubectl top pods names the missing Metrics API' "$top" 'Metrics API not available'

# Playground guide
guide=playground/docs/overview.md
expect 'guide: recent probe log lines carry the Pod name' "$(kubectl -n starfleet logs -l app=probe --prefix --tail=10)" '[pod/probe-'
guide_pods="$(kubectl get pods -A -o wide)"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$guide_pods" | awk '$1 == "starfleet" && $2 ~ /^probe-/ && $4 == "Running"' | wc -l | tr -d ' ')" 2
expect 'guide: shuttle is Running' "$(printf '%s\n' "$guide_pods" | awk '$1 == "starfleet" && $2 == "shuttle"')" Running
expect 'guide: drifter is Running' "$(printf '%s\n' "$guide_pods" | awk '$1 == "outpost" && $2 == "drifter"')" Running
expect 'guide: intruder is Running' "$(printf '%s\n' "$guide_pods" | awk '$1 == "outpost" && $2 == "intruder"')" Running
save_yaml_from_page "$guide" record-source.py
# record-source.py names the default context. Use the context of this run.
python3 - record-source.py "$context" <<'PY'
import sys
path, context = sys.argv[1:]
text = open(path).read()
open(path, 'w').write(text.replace('"kind-astro-ats-036-playground-030-03"', repr(context)))
PY
python3 record-source.py
finding="$(kubectl -n starfleet get configmap lateral-finding -o yaml)"
printf '%s\n' "$finding"
expect 'guide: finding names the intruder Pod' "$finding" 'sourcePod: intruder'
expect 'guide: finding names the outpost namespace' "$finding" 'sourceNamespace: outpost'
expect 'guide: finding names the target' "$finding" 'target: probe'
expect 'guide: finding has the finding value' "$finding" 'finding: lateral-movement-to-probe'
intruder_ip="$(kubectl get pods -A -o wide | awk '$1 == "outpost" && $2 == "intruder" {print $7}')"
expect 'guide: sourceIP is the IP column of intruder' "$finding" "sourceIP: $intruder_ip"
expect_equal 'guide: sourceIP is the address of the regular requests' "$intruder_ip" "$source_ip"

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
