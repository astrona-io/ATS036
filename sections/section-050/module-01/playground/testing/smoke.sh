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
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-050-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-playground-050-01}"
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
outpost_default=system:serviceaccount:outpost:default

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

# Fail unless the text has a line that is exactly the given line.
expect_line() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -qFx -- "$3" || { printf 'FAIL: %s\nwanted the line: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Fail when the text has a line that matches the extended regular expression.
expect_no_line() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  ! printf '%s\n' "$2" | grep -qE -- "$3" || { printf 'FAIL: %s\nunwanted line: %s\n' "$1" "$(printf '%s\n' "$2" | grep -E -- "$3" | head -3)" >&2; exit 1; }
}

# Run a command that the page says must fail and print its output. Stop when
# it succeeds.
expect_failure() {
  local output
  if output="$("$@" 2>&1)"; then
    printf 'FAIL: command unexpectedly succeeded: %s\n%s\n' "$*" "$output" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

# Run a command in the control plane node container, as the pages do with
# "$engine" exec "$node_name".
on_node() {
  "$engine" exec "$node_name" "$@"
}

# Run a page report script on the audit log until its output has a line that
# matches the extended regular expression, at most about 60 seconds: the API
# server writes the log a moment after the request. Print the last output.
report_with_line() {
  local script="$1" wanted="$2" output='' attempt
  for attempt in $(seq 1 30); do
    output="$(on_node cat "$audit_log" | python3 "$script")"
    printf '%s\n' "$output" | grep -qE -- "$wanted" && break
    sleep 2
  done
  printf '%s\n' "$output"
}

# The audit event model
page=course-01-the-audit-event-model.md
# The page selects the cluster with astrona kubeconfig. The CI script has
# already set KUBECONFIG, so only the context is checked.
expect_equal 'the playground context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'the Secret read prints secret/audit-token' "$(kubectl -n starfleet get secret audit-token -o name)" secret/audit-token
# Wait a moment for the file write, as the page says, then fall back to 200
# lines, as the page says when 40 lines print nothing.
event=''
for attempt in $(seq 1 30); do
  event="$(on_node tail -n 40 "$audit_log" | grep audit-token | tail -n 1 || true)"
  [[ -n "$event" ]] || event="$(on_node tail -n 200 "$audit_log" | grep audit-token | tail -n 1 || true)"
  [[ -n "$event" ]] && break
  sleep 2
done
formatted="$(printf '%s\n' "$event" | python3 -m json.tool)"
printf '%s\n' "$formatted"
expect 'the event has stage ResponseComplete' "$formatted" '"stage": "ResponseComplete"'
expect 'the event has verb get' "$formatted" '"verb": "get"'
expect 'the user is the kubeconfig administrator' "$formatted" '"username": "kubernetes-admin"'
expect 'the userAgent starts with kubectl' "$formatted" '"userAgent": "kubectl'
expect 'objectRef.resource is secrets' "$formatted" '"resource": "secrets"'
expect 'objectRef.name is audit-token' "$formatted" '"name": "audit-token"'
expect 'responseStatus.code is 200' "$formatted" '"code": 200'
expect_equal 'the event has no request or response body' "$(printf '%s\n' "$event" | python3 -c 'import json, sys; event = json.load(sys.stdin); print("requestObject" in event, "responseObject" in event)')" 'False False'

# Writing an audit policy
page=course-02-writing-an-audit-policy.md
policy="$(on_node cat /etc/kubernetes/training-audit-policy.json)"
printf '%s\n' "$policy"
expect_equal 'the policy file is one line of JSON' "$(printf '%s\n' "$policy" | grep -c .)" 1
policy_shape="$(printf '%s\n' "$policy" | python3 -c '
import json, sys
policy = json.load(sys.stdin)
first, second = policy["rules"]
print(policy["omitStages"], first["level"], first["namespaces"], sorted(first["resources"][0]["resources"]), second)')"
expect_equal 'the policy omits RequestReceived, records three resources in starfleet at Metadata and then None' "$policy_shape" "['RequestReceived'] Metadata ['starfleet'] ['configmaps', 'pods', 'secrets'] {'level': 'None'}"
save_file_from_page "$page" audit-count.py python
kubectl -n starfleet get secret audit-token -o name
kubectl -n starfleet get configmap probe-code -o name
kubectl -n starfleet get deployment probe -o name
kubectl -n outpost get pod drifter -o name
kubectl -n starfleet exec shuttle -- true
counts="$(report_with_line audit-count.py '^pods - get [0-9]+$' | sed 's/ [0-9]*$//')"
expect_line 'the counts have secrets - get' "$counts" 'secrets - get'
expect_line 'the counts have configmaps - get' "$counts" 'configmaps - get'
expect_line 'the counts have pods - get from kubectl exec' "$counts" 'pods - get'
expect_no_line 'the counts have no deployments line' "$counts" '^deployments '
expect_no_line 'the counts have no pods exec line' "$counts" '^pods exec '
expect_equal 'the log has no event for the outpost namespace' "$(on_node grep -c '"namespace":"outpost"' "$audit_log" || true)" 0

# API server flags, backends and troubleshooting
page=course-03-api-server-flags-backends-and-troubleshooting.md
flags="$(on_node grep -e '--audit' /etc/kubernetes/manifests/kube-apiserver.yaml)"
printf '%s\n' "$flags"
expect 'the policy file flag' "$flags" '--audit-policy-file=/etc/kubernetes/training-audit-policy.json'
expect 'the log path flag' "$flags" '--audit-log-path=/var/log/training-audit/audit.jsonl'
expect 'the maximum age flag' "$flags" '--audit-log-maxage=1'
expect 'the backup flag' "$flags" '--audit-log-maxbackup=1'
expect 'the maximum size flag' "$flags" '--audit-log-maxsize=10'
expect_equal 'the grep prints the one JSON line of the manifest' "$(printf '%s\n' "$flags" | grep -c .)" 1
mounts="$(on_node grep -n -A3 'training-audit' /etc/kubernetes/manifests/kube-apiserver.yaml)"
printf '%s\n' "$mounts"
# The manifest file holds the facts; read them from the parsed manifest so the
# check does not depend on the line layout of the file.
volume_facts="$(on_node cat /etc/kubernetes/manifests/kube-apiserver.yaml | python3 -c '
import json, sys
manifest = json.load(sys.stdin)
volumes = {volume["name"]: volume["hostPath"]["type"] for volume in manifest["spec"]["volumes"] if volume["name"].startswith("training-audit")}
mounts = {mount["name"]: bool(mount.get("readOnly")) for mount in manifest["spec"]["containers"][0]["volumeMounts"] if mount["name"].startswith("training-audit")}
print(volumes.get("training-audit-policy"), volumes.get("training-audit-log"), mounts.get("training-audit-policy"), mounts.get("training-audit-log"))')"
expect_equal 'policy volume File, log volume DirectoryOrCreate, policy mount read-only, log mount writable' "$volume_facts" 'File DirectoryOrCreate True False'
expect 'grep shows the policy volume of type File' "$mounts" 'File'
expect 'grep shows the log volume of type DirectoryOrCreate' "$mounts" 'DirectoryOrCreate'
log_listing="$(on_node ls -l /var/log/training-audit)"
printf '%s\n' "$log_listing"
expect 'the listing shows audit.jsonl' "$log_listing" audit.jsonl
apiserver_containers="$(on_node crictl ps -a --name kube-apiserver)"
printf '%s\n' "$apiserver_containers"
expect 'crictl lists a running kube-apiserver container' "$(printf '%s\n' "$apiserver_containers" | grep kube-apiserver)" Running
expect_equal 'the API is ready' "$(kubectl get --raw=/readyz)" ok

# Reading audit records to monitor access
page=course-04-reading-audit-records-to-monitor-access.md
expect_equal 'the administrator read prints secret/audit-token' "$(kubectl -n starfleet get secret audit-token -o name)" secret/audit-token
denied="$(expect_failure kubectl -n starfleet get secret audit-token --as="$outpost_default")"
expect_equal 'the impersonated read is Forbidden for the ServiceAccount and the Secret' "$denied" "Error from server (Forbidden): secrets \"audit-token\" is forbidden: User \"$outpost_default\" cannot get resource \"secrets\" in API group \"\" in the namespace \"starfleet\""
save_file_from_page "$page" audit-secret-report.py python
denied_line="kubernetes-admin $outpost_default get audit-token 403 forbid no-body"
report="$(report_with_line audit-secret-report.py "^$denied_line\$")"
expect_line 'the report has the allowed administrator read' "$report" 'kubernetes-admin - get audit-token 200 allow no-body'
expect_line 'the report has the denied impersonated read' "$report" "$denied_line"
expect_no_line 'every report line is no-body' "$report" ' body$'
expect_equal 'the Secret value is not in the log' "$(on_node grep -c 'audit-disposable' "$audit_log" || true)" 0

# Playground guide
guide=playground/docs/overview.md
# The guide sets KUBECONFIG with astrona kubeconfig and tests the context name.
expect_equal 'guide: the playground context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c Running)" 2
expect 'guide: shuttle is Running' "$(printf '%s\n' "$pods" | grep -E '^shuttle ')" Running
expect_equal 'guide: drifter is Running' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running
expect_equal 'guide: the probe Service exists' "$(kubectl -n starfleet get service probe -o name)" service/probe
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_equal 'guide: two nodes are Ready' "$(printf '%s\n' "$nodes" | awk 'NR > 1 && $2 == "Ready"' | grep -c .)" 2
expect_equal 'guide: audit-review is not configured yet' "$(kubectl -n starfleet get configmap audit-review --ignore-not-found -o name)" ''
save_file_from_page "$guide" configmap-audit-review.yaml
expect_equal 'guide: the Secret read prints secret/audit-token' "$(kubectl -n starfleet get secret audit-token -o name)" secret/audit-token
kubectl apply -f configmap-audit-review.yaml
configmaps="$(kubectl -n starfleet get configmaps)"
printf '%s\n' "$configmaps"
expect 'guide: audit-review is listed with three keys' "$(printf '%s\n' "$configmaps" | grep -E '^audit-review ')" '3'
expect_equal 'guide: audit-review records the result' "$(kubectl -n starfleet get configmap audit-review -o jsonpath='{.data.level} {.data.resource} {.data.result}')" 'Metadata secrets payload-excluded'
expect 'guide: the Deployment prints as YAML' "$(kubectl -n starfleet get deployment probe -o yaml)" 'kind: Deployment'
get_records="$(on_node cat "$audit_log" | python3 -c '
import json, sys
for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if event["stage"] == "ResponseComplete" and event["verb"] == "get" and reference.get("resource") == "secrets" and reference.get("name") == "audit-token":
        print("body" if "requestObject" in event or "responseObject" in event else "no-body")')"
expect_line 'guide: a ResponseComplete get record for audit-token exists' "$get_records" no-body
expect_no_line 'guide: no audit-token get record has a body' "$get_records" '^body$'
expect_equal 'guide: the API is ready' "$(kubectl get --raw=/readyz)" ok

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
