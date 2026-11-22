#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here. The pages write `"$engine" exec` for node commands, with
# engine from ASTRONA_CONTAINER_ENGINE (CI sets docker); this script does the
# same.
set -euo pipefail
playground=ats-036-playground-010-03
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
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
audit_log=/var/log/training-audit/audit.jsonl

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

# The record-audit.py of the guide names the default context and the node of
# a default start. It reads the container engine from ASTRONA_CONTAINER_ENGINE. Point the work copy at this environment, and fail
# when the page no longer contains the names that are replaced.
localize_script() {
  python3 - "$work_directory/$1" "$playground" "$engine" "$context" "$cluster" <<'PY'
import sys
path, playground, engine, context, cluster = sys.argv[1:]
text = open(path).read()
for old, new in [
    ('(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman")', '(os.environ.get("ASTRONA_CONTAINER_ENGINE") or ' + repr(engine) + ')'),
    ('"kind-astro-' + playground + '"', '"' + context + '"'),
    ('"astro-' + playground + '-control-plane"', '"' + cluster + '-control-plane"'),
    ("'astro-" + playground + "'", repr(cluster)),
]:
    if old not in text:
        sys.exit('expected ' + old + ' in ' + path)
    text = text.replace(old, new)
open(path, 'w').write(text)
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

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# The identity of the kubeconfig in use, which the setup exec also used.
my_username="$(kubectl auth whoami -o jsonpath='{.status.userInfo.username}')"
my_groups="$(kubectl auth whoami -o json | python3 -c 'import json, sys; print(json.load(sys.stdin)["status"]["userInfo"].get("groups"))')"

# Guided Practice: Find The Audit Record Of A Pod Exec
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ' || true)" 2
expect_match 'guide: the shuttle client Pod is Running' "$pods" '^shuttle +1/1 +Running '
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_equal 'guide: both nodes are Ready' "$(printf '%s\n' "$nodes" | grep -c ' Ready ' || true)" 2
# The guide saves configmap-exec-finding.yaml but does not apply it; the
# report comes from record-audit.py.
save_file_from_page "$page" configmap-exec-finding.yaml
save_file_from_page "$page" record-audit.py
localize_script record-audit.py
python3 record-audit.py
finding="$(kubectl -n starfleet get configmap exec-finding -o yaml)"
printf '%s\n' "$finding"
finding_field() { kubectl -n starfleet get configmap exec-finding -o jsonpath="{.data.$1}"; }
for field in resource subresource namespace finding; do
  wanted="$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["data"][sys.argv[2]])' configmap-exec-finding.yaml "$field")"
  expect_equal "guide: report field $field matches the saved YAML" "$(finding_field "$field")" "$wanted"
done
# The verb depends on the exec transport of kubectl: create (POST) or get
# (WebSocket GET), so the check accepts both.
expect_match 'guide: report verb is create or get' "$(finding_field verb)" '^(create|get)$'
expect_match 'guide: report stage is ResponseStarted or ResponseComplete' "$(finding_field stage)" '^Response(Started|Complete)$'
expect_match 'guide: report names a probe Pod' "$(finding_field podName)" '^probe-'
expect_equal 'guide: report names the authenticated user of the setup exec' "$(finding_field actor)" "$my_username"
expect 'guide: requestURI carries the requested command as command= parameters' "$(finding_field requestURI)" 'command=sh&command=-c&command=id'
audit_id="$(finding_field auditID)"
expect_match 'guide: report auditID matches an exec record in the log' "$("$engine" exec "$node_name" grep -F "\"auditID\":\"$audit_id\"" "$audit_log" | grep -c '"subresource":"exec"' || true)" '^[1-9]'
expect_match 'guide: the probe Deployment is unchanged with 2/2 ready' "$(kubectl -n starfleet get deployment probe)" '^probe +2/2 '

# Exec And Port-Forward In The Audit Log
page=course-01-exec-and-port-forward-in-the-audit-log.md
policy="$("$engine" exec "$node_name" cat /etc/kubernetes/training-audit-policy.json)"
printf '%s\n' "$policy"
expect_equal 'policy has the Metadata rule for starfleet and the final None rule' "$(printf '%s' "$policy" | python3 -c '
import json, sys
policy = json.load(sys.stdin)
first, last = policy["rules"][0], policy["rules"][-1]
print(first["level"], first["namespaces"], first["resources"][0]["resources"], last["level"])
')" "Metadata ['starfleet'] ['secrets', 'configmaps', 'pods', 'pods/exec', 'pods/portforward'] None"
expect 'the exec prints the user ID' "$(kubectl -n starfleet exec deploy/probe -- sh -c 'id')" 'uid=0(root)'
save_file_from_page "$page" exec-report.py
# The setup exec and the exec above: wait at most 60 seconds for two requests.
report=''
for attempt in $(seq 1 30); do
  report="$("$engine" exec "$node_name" cat "$audit_log" | python3 exec-report.py)"
  [[ "$(printf '%s\n' "$report" | awk 'NF {print $2}' | sort -u | wc -l | tr -d ' ')" -ge 2 ]] && break
  sleep 2
done
printf '%s\n' "$report"
expect_equal 'two exec requests, one auditID each' "$(printf '%s\n' "$report" | awk 'NF {print $2}' | sort -u | wc -l | tr -d ' ')" 2
expect_equal 'every line is a create or get on a probe Pod in starfleet' "$(printf '%s\n' "$report" | awk 'NF && !(($5 == "create" || $5 == "get") && $6 == "starfleet" && $7 ~ /^probe-/)' | wc -l | tr -d ' ')" 0
expect_equal 'every line has an exec request URI with the command parameters' "$(printf '%s\n' "$report" | grep -c '/exec?command=sh&command=-c&command=id' || true)" "$(printf '%s\n' "$report" | grep -c . || true)"
expect_equal 'every stage is ResponseStarted or ResponseComplete' "$(printf '%s\n' "$report" | awk 'NF && $3 != "ResponseStarted" && $3 != "ResponseComplete"' | wc -l | tr -d ' ')" 0

# Who Sent The Request: Identity And Origin
page=course-02-who-sent-the-request-identity-and-origin.md
save_file_from_page "$page" identity-report.py
identities="$("$engine" exec "$node_name" cat "$audit_log" | python3 identity-report.py)"
printf '%s\n' "$identities"
expect_equal 'every exec line names your username and groups' "$(printf '%s\n' "$identities" | grep -cF " $my_username $my_groups " || true)" "$(printf '%s\n' "$identities" | grep -c . || true)"
expect_equal 'no exec request used impersonation' "$(printf '%s\n' "$identities" | grep -cF "$my_groups None " || true)" "$(printf '%s\n' "$identities" | grep -c . || true)"
expect_equal 'every userAgent is kubectl followed by its version' "$(printf '%s\n' "$identities" | grep -cE ' kubectl/v[0-9]' || true)" "$(printf '%s\n' "$identities" | grep -c . || true)"

# Correlating Audit Records With Other Evidence
page=course-03-correlating-audit-records-with-other-evidence.md
probe_pods="$(kubectl -n starfleet get pods -l app=probe -o wide)"
printf '%s\n' "$probe_pods"
expect_equal 'the NODE column names the worker for both probe Pods' "$(printf '%s\n' "$probe_pods" | grep -E '^probe-' | grep -c " $worker_name " || true)" 2
expect_match 'the container ID starts with the runtime name and ://' "$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].containerID}{"\n"}')" '^[a-z]+://[0-9a-f]+$'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
