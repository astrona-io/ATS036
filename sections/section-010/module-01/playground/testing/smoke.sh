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
playground=ats-036-playground-010-01
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
threat_reader=system:serviceaccount:starfleet:threat-reader

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

# Guided Practice: Detect A Denied API Access Attempt
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
save_file_from_page "$page" configmap-audit-finding.yaml
save_file_from_page "$page" record-audit.py
localize_script record-audit.py
python3 record-audit.py
configmaps="$(kubectl -n starfleet get configmaps)"
printf '%s\n' "$configmaps"
expect_match 'guide: the audit-finding ConfigMap exists' "$configmaps" '^audit-finding '
finding="$(kubectl -n starfleet get configmap audit-finding -o json)"
finding_field() { printf '%s' "$finding" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"].get(sys.argv[1], ""))' "$1"; }
# The guide saves configmap-audit-finding.yaml with the fields it expects; the
# report written from the real record must hold the same values.
for field in actor resource namespace code finding; do
  wanted="$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["data"][sys.argv[2]])' configmap-audit-finding.yaml "$field")"
  expect_equal "guide: report field $field matches the saved YAML" "$(finding_field "$field")" "$wanted"
done
expect_equal 'guide: report stage is ResponseComplete' "$(finding_field stage)" ResponseComplete
expect_equal 'guide: report requestURI names audit-token' "$(finding_field requestURI)" /api/v1/namespaces/starfleet/secrets/audit-token
audit_id="$(finding_field auditID)"
expect_equal 'guide: report auditID belongs to a denied record in the log' "$("$engine" exec "$node_name" grep -F "\"auditID\":\"$audit_id\"" "$audit_log" | grep -c '"code":403' || true)" 1
expect_equal 'guide: no credential value in the report' "$(printf '%s' "$finding" | grep -c audit-disposable || true)" 0
expect 'guide: probe Deployment still has two ready replicas' "$(kubectl -n starfleet get deployment probe -o yaml)" 'readyReplicas: 2'

# Expected Behavior Of A Workload
page=course-01-expected-behavior-of-a-workload.md
expect_equal 'the private context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'probe command is python /app/server.py' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].command}{"\n"}')" '["python","/app/server.py"]'
port_and_account="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}{"\n"}{.spec.template.spec.serviceAccountName}{"\n"}')"
expect_equal 'port is 8080 and the ServiceAccount line is empty' "$port_and_account" 8080
processes="$(kubectl -n starfleet exec deploy/probe -- ps)"
printf '%s\n' "$processes"
expect_match 'process 1 is python /app/server.py' "$processes" '^ *1 +[a-z]+ +[0-9:]+ python /app/server.py$'
expect_match 'the ps command is listed' "$processes" ' ps$'
response="$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe.starfleet.svc)"
printf '%s\n' "$response"
expect_match 'probe answers version=v1 host=... greeting=hello' "$response" '^version=v1 host=.* greeting=hello$'
identity="$(kubectl -n starfleet exec deploy/probe -- sh -c 'id')"
printf '%s\n' "$identity"
expect 'the shell runs as user ID 0, root' "$identity" 'uid=0(root)'

# Syscalls, eBPF And Falco Rules
page=course-02-syscalls-ebpf-and-falco-rules.md
container_kernel="$(kubectl -n starfleet exec deploy/probe -- uname -r)"
node_kernel="$("$engine" exec "$worker_name" uname -r)"
printf '%s\n%s\n' "$container_kernel" "$node_kernel"
expect_equal 'container and worker node print the same kernel release' "$container_kernel" "$node_kernel"
# The Falco rule on this page is shown to read, not applied.
expect_equal 'ls /app in the probe container prints server.py' "$(kubectl -n starfleet exec deploy/probe -- sh -c 'ls /app')" server.py

# Audit Records As Behavioral Evidence
page=course-03-audit-records-as-behavioral-evidence.md
policy="$("$engine" exec "$node_name" cat /etc/kubernetes/training-audit-policy.json)"
printf '%s\n' "$policy"
expect_equal 'policy has the version, omitStages and two rules the page describes' "$(printf '%s' "$policy" | python3 -c '
import json, sys
policy = json.load(sys.stdin)
first, last = policy["rules"][0], policy["rules"][-1]
print(policy["apiVersion"], policy["omitStages"], len(policy["rules"]), first["level"], first["namespaces"], first["resources"][0]["resources"], last["level"])
')" "audit.k8s.io/v1 ['RequestReceived'] 2 Metadata ['starfleet'] ['secrets', 'configmaps', 'pods'] None"
expect_equal 'request.py prints denied-secret-read' "$(kubectl -n starfleet exec threat-client -- python /app/request.py)" denied-secret-read
save_file_from_page "$page" audit-report.py
# One denied line for the start-up run and one for the run above; wait at most
# 60 seconds for the second one.
denied_line="ResponseComplete $threat_reader get secrets starfleet audit-token 403"
report=''
for attempt in $(seq 1 30); do
  report="$("$engine" exec "$node_name" cat "$audit_log" | python3 audit-report.py threat-reader)"
  [[ "$(printf '%s\n' "$report" | grep -cF "$denied_line" || true)" -ge 2 ]] && break
  sleep 2
done
printf '%s\n' "$report"
expect_equal 'one denied get line for each run of the script' "$(printf '%s\n' "$report" | grep -cF "$denied_line" || true)" 2
expect_equal 'every auditID in the report is different' "$(printf '%s\n' "$report" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')" "$(printf '%s\n' "$report" | grep -c . || true)"
last_denial="$("$engine" exec "$node_name" grep '"code":403' "$audit_log" | tail -n 1)"
expect_equal 'last denial has the URI, user, decision and no bodies the page names' "$(printf '%s' "$last_denial" | python3 -c '
import json, sys
event = json.load(sys.stdin)
print(event["requestURI"], event["user"]["username"], event["annotations"]["authorization.k8s.io/decision"], "requestObject" in event, "responseObject" in event)
')" "/api/v1/namespaces/starfleet/secrets/audit-token $threat_reader forbid False False"

# Triage, Tuning And Response To An Alert
page=course-04-triage-tuning-and-response.md
# The Falco override on this page is shown to read, not applied.
kubectl -n starfleet get pod shuttle -o yaml > shuttle-evidence.yaml
kubectl -n starfleet logs shuttle --timestamps > shuttle-logs.txt
expect 'evidence file holds the shuttle Pod object' "$(cat shuttle-evidence.yaml)" 'name: shuttle'
expect 'evidence file holds the ServiceAccount' "$(cat shuttle-evidence.yaml)" 'serviceAccountName: default'
expect 'evidence file holds the node' "$(cat shuttle-evidence.yaml)" "nodeName: $worker_name"
expect_equal 'shuttle log file is empty' "$(wc -c < shuttle-logs.txt | tr -d ' ')" 0
kubectl -n starfleet debug shuttle --image=docker.io/library/busybox:1.37.0 --target=client --container=evidence -- ps
# The ephemeral container must start first; read its log for at most 60 seconds.
evidence_log=''
for attempt in $(seq 1 30); do
  evidence_log="$(kubectl -n starfleet logs shuttle -c evidence 2>/dev/null || true)"
  [[ "$evidence_log" == *'sleep 3600'* ]] && break
  sleep 2
done
printf '%s\n' "$evidence_log"
expect 'ephemeral container ps lists sleep 3600 of client' "$evidence_log" 'sleep 3600'
suspect_pod="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')"
kubectl -n starfleet label pod "$suspect_pod" app=probe-quarantine --overwrite
# "After a few seconds": wait at most 60 seconds for the replacement Pod.
listing=''
for attempt in $(seq 1 30); do
  listing="$(kubectl -n starfleet get pods -L app)"
  [[ "$(printf '%s\n' "$listing" | grep -cE '^probe-' || true)" -ge 3 ]] && break
  sleep 2
done
printf '%s\n' "$listing"
expect_equal 'listing shows three probe Pods' "$(printf '%s\n' "$listing" | grep -cE '^probe-' || true)" 3
expect_equal 'two probe Pods have app=probe' "$(printf '%s\n' "$listing" | grep -E '^probe-' | awk '$NF == "probe"' | wc -l | tr -d ' ')" 2
expect_match 'the labelled Pod has app=probe-quarantine' "$listing" "^$suspect_pod .* probe-quarantine\$"
# The Service and the ReplicaSet let the Pod go; wait at most 60 seconds.
endpoints=''
owners=''
for attempt in $(seq 1 30); do
  endpoints="$(kubectl -n starfleet get endpointslices -l kubernetes.io/service-name=probe -o jsonpath='{.items[*].endpoints[*].targetRef.name}')"
  owners="$(kubectl -n starfleet get pod "$suspect_pod" -o jsonpath='{.metadata.ownerReferences}')"
  [[ "$endpoints" != *"$suspect_pod"* && -z "$owners" ]] && break
  sleep 2
done
expect_equal 'the Service no longer selects the quarantined Pod' "$(printf '%s' "$endpoints" | grep -c "$suspect_pod" || true)" 0
expect_equal 'the ReplicaSet no longer owns the quarantined Pod' "$owners" ''
# --timeout bounds the wait of the page command.
kubectl -n starfleet delete pod "$suspect_pod" --timeout=120s
expect 'the quarantined Pod is gone' "$(kubectl -n starfleet get pod "$suspect_pod" 2>&1 || true)" NotFound

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
