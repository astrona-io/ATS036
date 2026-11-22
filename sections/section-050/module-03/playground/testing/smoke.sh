#!/usr/bin/env bash
# Runs the commands that the module pages teach against the playground cluster
# and fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The bootstrap has already turned on auditing. The pages
# show no command output, so each check tests the fact that the prose around
# the command states. The pages run node commands with podman; this script
# uses the container engine of the run (CI sets docker) and only the node
# containers of this playground.
set -euo pipefail
playground=ats-036-playground-050-03
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

# Run a command in the control plane node container, as the pages do with
# podman exec "$node_name".
on_node() {
  "$engine" exec "$node_name" "$@"
}

audit_flag_lines="--audit-policy-file=/etc/kubernetes/training-audit-policy.json
--audit-log-path=$audit_log
--audit-log-maxage=1
--audit-log-maxbackup=1
--audit-log-maxsize=10"

# Rotation flags and disk use
page=course-01-rotation-flags-and-disk-use.md
# The page selects the cluster with astrona kubeconfig. The CI script has
# already set KUBECONFIG, so only the context is checked.
expect_equal 'the playground context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'the page names the control plane node of the playground' "$(value_from_page "$page" node_name)" "astro-$playground-control-plane"
flags="$(on_node grep -o -- '--audit-[a-z-]*=[^"]*' /etc/kubernetes/manifests/kube-apiserver.yaml)"
printf '%s\n' "$flags"
expect_equal 'the policy file, the log path and the three rotation flags (age 1, backups 1, size 10)' "$(printf '%s\n' "$flags" | sort)" "$(printf '%s\n' "$audit_flag_lines" | sort)"
log_listing="$(on_node ls -l /var/log/training-audit)"
printf '%s\n' "$log_listing"
expect 'the directory holds audit.jsonl' "$log_listing" ' audit.jsonl'
expect_equal 'every file is audit.jsonl or a rotated audit file' "$(printf '%s\n' "$log_listing" | awk 'NR > 1 {print $NF}' | grep -cvE '^audit(-[0-9T:.-]+)?\.jsonl$' || true)" 0

# Protecting the log file
page=course-02-protecting-the-log-file.md
expect_equal 'the page names the control plane node of the playground' "$(value_from_page "$page" node_name)" "astro-$playground-control-plane"
file_stat="$(on_node stat -c '%a %U %n' "$audit_log")"
printf '%s\n' "$file_stat"
expect_equal 'the file stat shows an octal mode, the owner root and the name' "$(printf '%s\n' "$file_stat" | sed -E 's/^[0-7]{3,4} /<mode> /')" "<mode> root $audit_log"
directory_stat="$(on_node stat -c '%a %U %n' /var/log/training-audit)"
printf '%s\n' "$directory_stat"
expect_equal 'the directory stat shows an octal mode, the owner root and the name' "$(printf '%s\n' "$directory_stat" | sed -E 's/^[0-7]{3,4} /<mode> /')" '<mode> root /var/log/training-audit'

# Forwarding and retention policy: the page has no commands.

# Verify delivery to an audit webhook: skipped. The page runs inside the VM of
# the webhook delivery lab (audit-collector.service and the kubeadm files in
# /etc/kubernetes/audit). None of these exist in this kind playground; the lab
# tests its own environment.

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
expect_equal 'guide: audit-retention is not configured yet' "$(kubectl -n starfleet get configmap audit-retention --ignore-not-found -o name)" ''
expect_equal 'guide: the audit flags' "$(on_node grep -o -- '--audit-[a-z-]*=[^"]*' /etc/kubernetes/manifests/kube-apiserver.yaml | sort)" "$(printf '%s\n' "$audit_flag_lines" | sort)"
guide_stat="$(on_node stat -c '%a %U %n' "$audit_log")"
expect 'guide: the file stat names the owner and the file' "$guide_stat" " root $audit_log"
save_file_from_page "$guide" record-retention.py python
# The script of the page runs podman. Use the container engine of this run in
# the work copy, the same way this script runs the podman exec commands.
sed -i.orig "s/\['podman', 'exec'/['$engine', 'exec'/" record-retention.py
expect 'guide: the work copy runs the container engine of this run' "$(cat record-retention.py)" "['$engine', 'exec', node_name"
python3 record-retention.py "$node_name" > configmap-audit-retention.json
kubectl apply -f configmap-audit-retention.json
kubectl -n starfleet get configmap audit-retention -o yaml
retention="$(kubectl -n starfleet get configmap audit-retention -o jsonpath='{.data.policyFile} {.data.logPath} {.data.maxAge} {.data.maxBackup} {.data.maxSize}')"
expect_equal 'guide: the ConfigMap holds the live flag values' "$retention" "/etc/kubernetes/training-audit-policy.json $audit_log 1 1 10"
expect_equal 'guide: logMode equals the mode in the stat output' "$(kubectl -n starfleet get configmap audit-retention -o jsonpath='{.data.logMode}')" "$(on_node stat -c '%a' "$audit_log")"
expect 'guide: the log directory still holds audit.jsonl' "$(on_node ls -l /var/log/training-audit)" ' audit.jsonl'
expect_equal 'guide: the API server was not changed and is ready' "$(kubectl get --raw=/readyz)" ok

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
