#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages start with
# `export KUBECONFIG="$(astrona kubeconfig ...)"`; the runner has already done
# that, so the script skips it. The pages read the audit log with
# `podman exec`; the script uses the container engine of the run instead.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-030-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-playground-030-01}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages write their files to the current directory.
cd "$work_directory"
node_name="$cluster-control-plane"
threat_reader=system:serviceaccount:starfleet:threat-reader
audit_log=/var/log/training-audit/audit.jsonl

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

# Print the audit log of the control plane node, as the pages do.
audit_records() {
  "$engine" exec "$node_name" cat "$audit_log"
}

# Attack phases in Kubernetes
page=course-01-attack-phases-in-kubernetes.md
expect_equal 'current context is the playground' "$(kubectl config current-context)" "$context"
status=0
answer="$(kubectl -n starfleet auth can-i get secrets/audit-token --as="$threat_reader")" || status=$?
expect_equal 'threat-reader may not get audit-token' "$answer" no
expect_equal 'the no answer exits with status 1' "$status" 1
review="$(kubectl -n starfleet auth can-i --list --as="$threat_reader")"
printf '%s\n' "$review"
expect 'review lists selfsubjectaccessreviews' "$review" selfsubjectaccessreviews.authorization.k8s.io
expect 'review lists selfsubjectrulesreviews' "$review" selfsubjectrulesreviews.authorization.k8s.io
expect 'review lists non-resource URLs' "$review" '[/healthz]'
expect_equal 'review has no row for secrets' "$(printf '%s\n' "$review" | grep -cE '^secrets ' || true)" 0

# Actor identity in audit records
page=course-02-actor-identity-in-audit-records.md
save_yaml_from_page "$page" audit-actor.py
actor_blocks="$(audit_records | python3 audit-actor.py threat-reader)"
printf '%s\n' "$actor_blocks"
last_block="$(printf '%s\n' "$actor_blocks" | awk 'BEGIN {RS = ""} {block = $0} END {print block}')"
expect 'last block names the threat-reader user' "$last_block" "username: $threat_reader"
expect 'last block groups include system:serviceaccounts:starfleet' "$last_block" "'system:serviceaccounts:starfleet'"
expect 'last block is a get on audit-token' "$last_block" 'request: get /api/v1/namespaces/starfleet/secrets/audit-token'
expect 'last block has the code 403' "$last_block" 'code: 403'
expect 'last block names the secrets resource' "$last_block" 'resource: secrets audit-token'
expect 'userAgent names the urllib library' "$last_block" 'userAgent: Python-urllib'
pod_identity="$(kubectl -n starfleet get pod threat-client -o jsonpath='{.status.podIP}{" "}{.metadata.uid}{"\n"}')"
printf '%s\n' "$pod_identity"
pod_uid="${pod_identity#* }"
expect 'extra names the Pod threat-client' "$last_block" "'authentication.kubernetes.io/pod-name': ['threat-client']"
expect 'extra pod-uid is the live Pod UID' "$last_block" "'authentication.kubernetes.io/pod-uid': ['$pod_uid']"
live_identity="$(kubectl -n starfleet get pod threat-client -o jsonpath='{.metadata.name}{"\t"}{.metadata.uid}{"\t"}{.status.podIP}{"\n"}')"
printf '%s\n' "$live_identity"
expect_equal 'live identity has name, UID and IP' "$(printf '%s\n' "$live_identity" | cut -f1,2)" "$(printf 'threat-client\t%s' "$pod_uid")"
# The page shows the pattern `kubectl create configmap <report>
# --from-literal=<key>=<value>` only as a template with placeholders, so the
# script does not run it. The playground guide records the report below.

# Building a timeline from several sources
page=course-03-building-a-timeline-from-several-sources.md
save_yaml_from_page "$page" audit-timeline.py
timeline="$(audit_records | python3 audit-timeline.py)"
printf '%s\n' "$timeline"
expect_equal 'timeline is sorted by time' "$timeline" "$(printf '%s\n' "$timeline" | LC_ALL=C sort -s -k1,1)"
expect 'timeline holds the threat-reader 403 event' "$timeline" "$threat_reader get secrets audit-token 403"
expect 'timeline holds the identity that set up the playground' "$timeline" ' kubernetes-admin '
expect_equal 'timeline holds only Secrets, ConfigMaps and Pods' "$(printf '%s\n' "$timeline" | awk '$4 != "secrets" && $4 != "configmaps" && $4 != "pods"' | wc -l | tr -d ' ')" 0
# The page also says the timeline holds kube-system controllers that create
# Pods and that the threat-reader event comes at the end. The audit policy is
# switched on after the playground objects exist, and the commands above add
# later events, so the script does not check these two claims.
owners="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.creationTimestamp}{" "}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}{end}')"
printf '%s\n' "$owners"
expect_equal 'every probe Pod is owned by a probe ReplicaSet' "$(printf '%s\n' "$owners" | grep -vc ' ReplicaSet/probe-' || true)" 0
replica_owners="$(kubectl -n starfleet get replicaset -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}{end}')"
printf '%s\n' "$replica_owners"
expect 'ReplicaSet owner is Deployment/probe' "$replica_owners" ' Deployment/probe'
threat_owner="$(kubectl -n starfleet get pod threat-client -o jsonpath='{.metadata.ownerReferences}{"\n"}{.metadata.creationTimestamp}{"\n"}')"
printf '%s\n' "$threat_owner"
expect_equal 'first line is empty: nothing owns threat-client' "$(printf '%s\n' "$threat_owner" | sed -n 1p)" ''
created="$(printf '%s\n' "$threat_owner" | sed -n 2p)"
denied_at="$(printf '%s\n' "$timeline" | grep "$threat_reader get secrets audit-token 403" | tail -1 | cut -d' ' -f1)"
checks=$((checks + 1))
printf 'check: %s\n' 'denied request is later than the Pod creation time'
[[ "$denied_at" > "$created" ]] || { printf 'FAIL: event %s is not after %s\n' "$denied_at" "$created" >&2; exit 1; }

# Containment and evidence preservation
page=course-04-containment-and-evidence-preservation.md
kubectl -n starfleet get pod threat-client -o yaml > threat-client-evidence.yaml
kubectl -n starfleet logs threat-client --timestamps > threat-client-logs.txt
evidence="$(cat threat-client-evidence.yaml)"
expect 'evidence has the image' "$evidence" 'image: docker.io/library/python:3.13-alpine'
expect 'evidence has the image digest' "$(printf '%s\n' "$evidence" | grep 'imageID: ')" 'sha256:'
expect 'evidence has the ServiceAccount' "$evidence" 'serviceAccountName: threat-reader'
expect 'evidence has the node' "$evidence" 'nodeName: '
expect 'evidence has the start time' "$evidence" 'startTime: '
expect 'evidence has the container status' "$evidence" 'containerStatuses:'
expect_equal 'log file is empty' "$(wc -c < threat-client-logs.txt | tr -d ' ')" 0
suspect_pod="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')"
kubectl -n starfleet delete pod "$suspect_pod"
probe_pods="$(kubectl -n starfleet get pods -l app=probe)"
printf '%s\n' "$probe_pods"
expect_equal 'listing shows two probe Pods' "$(printf '%s\n' "$probe_pods" | grep -c '^probe-')" 2
expect_absent 'the deleted Pod is gone' "$probe_pods" "$suspect_pod "
kubectl -n starfleet rollout status deployment/probe --timeout=180s
persistence="$(kubectl -n starfleet get rolebindings,cronjobs,jobs 2>&1)"
expect_equal 'no RoleBindings, CronJobs or Jobs' "$persistence" 'No resources found in starfleet namespace.'
expect 'ClusterRoleBindings are listed by age' "$(kubectl get clusterrolebindings --sort-by=.metadata.creationTimestamp)" cluster-admin

# Playground guide
guide=playground/docs/overview.md
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ')" 2
expect 'guide: shuttle is Running' "$(printf '%s\n' "$pods" | grep -E '^shuttle ')" Running
expect 'guide: threat-client is Running' "$(printf '%s\n' "$pods" | grep -E '^threat-client ')" Running
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_equal 'guide: both nodes are Ready' "$(printf '%s\n' "$nodes" | awk 'NR > 1 && $2 == "Ready"' | wc -l | tr -d ' ')" 2
# The guide saves the ConfigMap file and then records the report with
# record-audit.py, which applies the ConfigMap itself.
save_yaml_from_page "$guide" configmap-audit-finding.yaml
expect 'guide: saved ConfigMap names the finding' "$(cat configmap-audit-finding.yaml)" 'finding: unauthorized-secret-read'
save_yaml_from_page "$guide" record-audit.py
# record-audit.py names the default context, the default cluster and podman.
# Use the values of this run instead, so the script also works with docker.
python3 - record-audit.py "$context" "$cluster" "$engine" <<'PY'
import sys
path, context, cluster, engine = sys.argv[1:]
text = open(path).read()
text = text.replace('"kind-astro-ats-036-playground-030-01"', repr(context))
text = text.replace('astro-ats-036-playground-030-01', cluster)
text = text.replace("'podman'", repr(engine))
open(path, 'w').write(text)
PY
python3 record-audit.py
configmaps="$(kubectl -n starfleet get configmaps)"
printf '%s\n' "$configmaps"
expect 'guide: ConfigMap audit-finding exists' "$configmaps" audit-finding
report="$(kubectl -n starfleet get configmap audit-finding -o json)"
expect_equal 'guide: report names the actor' "$(printf '%s' "$report" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["actor"])')" "$threat_reader"
expect_equal 'guide: report has the code 403' "$(printf '%s' "$report" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["code"])')" 403
expect_equal 'guide: report has the stage ResponseComplete' "$(printf '%s' "$report" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["stage"])')" ResponseComplete
audit_id="$(printf '%s' "$report" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["auditID"])')"
expect 'guide: report auditID is a denied record in the audit log' "$(audit_records | grep "\"auditID\":\"$audit_id\"" | grep '"stage":"ResponseComplete"')" '"code":403'
expect_absent 'guide: report holds no credential body' "$report" audit-disposable
expect 'guide: probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o yaml)" 'readyReplicas: 2'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
