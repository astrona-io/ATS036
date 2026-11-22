#!/usr/bin/env bash
# Runs the commands that the module pages teach against the playground cluster
# and fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The bootstrap has already turned on auditing. The pages
# show no command output, so each check tests the fact that the prose around
# the command states. The pages run node commands with "$engine" exec; this
# script uses the container engine of the run (CI sets docker) and only the node
# containers of this playground.
set -euo pipefail
playground=ats-036-playground-050-02
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
# The pages use the saved files by their bare names.
cd "$work_directory"
node_name="$cluster-control-plane"
audit_log=/var/log/training-audit/audit.jsonl

# Write the code block in the given language (yaml or python) that follows
# "Save this as `<file>`" on a page.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" "${3:-yaml}" <<'PY'
import re, sys
page, name, target, language = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```' + language + r'\n(.*?)```', text, re.S)
if not match:
    sys.exit('no ' + language + ' block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Print the value that a page assigns to a shell variable, for example
# node_name="...", or the context name that a page tests with
# test "$(kubectl config current-context)" = "...".
value_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, name = sys.argv[1:]
text = open(page).read()
if name == 'context':
    match = re.search(r'current-context\)" = "([^"]*)"', text)
else:
    match = re.search(r'^' + re.escape(name) + r'="([^"]*)"', text, re.M)
if not match:
    sys.exit('no value for ' + name + ' in ' + page)
print(match.group(1))
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Fail unless the text has a line that matches the extended regular expression.
expect_line() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -qE -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Run a command in the control plane node container, as the pages do with
# "$engine" exec "$node_name".
on_node() {
  "$engine" exec "$node_name" "$@"
}

# Subresources in audit policy rules
page=course-01-subresources-in-audit-policy-rules.md
# The page selects the cluster with astrona kubeconfig. The CI script has
# already set KUBECONFIG, so only the context is checked.
expect_equal 'the playground context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'the page names the control plane node of the playground' "$(value_from_page "$page" node_name)" "astro-$playground-control-plane"
policy="$(on_node cat /etc/kubernetes/training-audit-policy.json)"
printf '%s\n' "$policy"
expect_equal 'the policy is one line of JSON' "$(printf '%s\n' "$policy" | grep -c .)" 1
policy_shape="$(printf '%s\n' "$policy" | python3 -c '
import json, sys
policy = json.load(sys.stdin)
first, second, last = policy["rules"]
print(policy["omitStages"], first["level"], first["namespaces"], first["resources"][0]["resources"], second["level"], sorted(second["resources"][0]["resources"]), last)')"
expect_equal 'omitStages RequestReceived, a Metadata rule for three Pod subresources in starfleet, a Secret and ConfigMap rule, then None' "$policy_shape" "['RequestReceived'] Metadata ['starfleet'] ['pods/exec', 'pods/portforward', 'pods/log'] Metadata ['configmaps', 'secrets'] {'level': 'None'}"

# Recording and reading exec events
page=course-02-recording-and-reading-exec-events.md
expect_equal 'the page names the control plane node of the playground' "$(value_from_page "$page" node_name)" "astro-$playground-control-plane"
identity="$(kubectl -n starfleet exec shuttle -- id)"
printf '%s\n' "$identity"
expect 'the command prints the user ID' "$identity" 'uid='
expect 'the command prints the group ID' "$identity" 'gid='
save_file_from_page "$page" audit-pod-access.py python
# The page reads the log once; retry for at most about 60 seconds, because the
# API server writes the ResponseComplete event when the exec stream ends.
exec_record='^kubernetes-admin (get|create) exec shuttle [^ ]+ /api/v1/namespaces/starfleet/pods/shuttle/exec\?.*command=id'
report=''
for attempt in $(seq 1 30); do
  report="$(on_node cat "$audit_log" | python3 audit-pod-access.py)"
  printf '%s\n' "$report" | grep -qE -- "$exec_record" && break
  sleep 2
done
printf '%s\n' "$report"
expect_line 'the report has the exec of shuttle by the kubeconfig user with command=id' "$report" "$exec_record"
expect_line 'the requestURI names the stdout option' "$(printf '%s\n' "$report" | grep -E -- "$exec_record")" 'stdout=true'
exec_events="$(on_node cat "$audit_log" | python3 -c '
import json, sys
for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("subresource") == "exec" and reference.get("name") == "shuttle":
        print(event["stage"], reference["resource"], reference["namespace"], "body" if "requestObject" in event or "responseObject" in event else "no-body")')"
printf '%s\n' "$exec_events"
expect_line 'the exec event stores resource pods and namespace starfleet' "$exec_events" '^ResponseComplete pods starfleet '
expect_equal 'no exec event holds a body' "$(printf '%s\n' "$exec_events" | grep -c ' body$' || true)" 0
expect_equal 'no exec event has stage RequestReceived' "$(printf '%s\n' "$exec_events" | grep -c '^RequestReceived ' || true)" 0
expect_equal 'the command output is not in the log' "$(on_node grep -c 'uid=0(root)' "$audit_log" || true)" 0

# Choosing rules and levels for interactive access: the page has no commands.

# Playground guide
guide=playground/docs/overview.md
expect_equal 'guide: the context the guide tests is the playground context' "$(value_from_page "$guide" context)" "kind-astro-$playground"
expect_equal 'guide: the guide names the control plane node' "$(value_from_page "$guide" node_name)" "astro-$playground-control-plane"
expect_equal 'guide: the guide names the worker node' "$(value_from_page "$guide" worker_name)" "astro-$playground-worker"
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c Running)" 2
expect 'guide: shuttle is Running' "$(printf '%s\n' "$pods" | grep -E '^shuttle ')" Running
expect_equal 'guide: drifter is Running' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running
expect_equal 'guide: the probe Service exists' "$(kubectl -n starfleet get service probe -o name)" service/probe
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_equal 'guide: two nodes are Ready' "$(printf '%s\n' "$nodes" | awk 'NR > 1 && $2 == "Ready"' | grep -c .)" 2
expect_equal 'guide: audit-exec is not configured yet' "$(kubectl -n starfleet get configmap audit-exec --ignore-not-found -o name)" ''
expect 'guide: id runs in shuttle' "$(kubectl -n starfleet exec shuttle -- id)" 'uid='
save_file_from_page "$guide" configmap-audit-exec.yaml
kubectl apply -f configmap-audit-exec.yaml
report_yaml="$(kubectl -n starfleet get configmap audit-exec -o yaml)"
printf '%s\n' "$report_yaml"
expect_equal 'guide: audit-exec holds the five fields' "$(kubectl -n starfleet get configmap audit-exec -o jsonpath='{.data.resource} {.data.subresource} {.data.podName} {.data.command} {.data.level}')" 'pods exec shuttle id Metadata'
exec_count="$(on_node grep -c 'pods/shuttle/exec' "$audit_log" || true)"
printf '%s\n' "$exec_count"
[[ "$exec_count" =~ ^[0-9]+$ && "$exec_count" -gt 0 ]] && count_result='greater than 0' || count_result="$exec_count"
expect_equal 'guide: the count of shuttle exec lines is greater than 0' "$count_result" 'greater than 0'
expect_equal 'guide: the API is ready' "$(kubectl get --raw=/readyz)" ok

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
