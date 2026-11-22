#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-036-playground-020-02
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
# No page of this module runs a node command, so "$engine" and "$cluster" are
# only part of the shared guard settings.

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

# Guided Practice: Report A Risky Pod Specification
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'guide: the container of suspect-pod is privileged' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}')" true
expect_equal 'guide: suspect-pod mounts the node directory /etc' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.volumes[*].hostPath.path}{"\n"}')" /etc
expect 'guide: apply creates pod-risk-report' "$(save_from_page "$page" configmap-pod-risk-report.yaml)" 'configmap/pod-risk-report created'
expect_equal 'guide: suspect-pod is still privileged' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}')" true
expect_equal 'guide: the report holds pod, privileged and hostPath' "$(kubectl -n starfleet get configmap pod-risk-report -o jsonpath='{.data}{"\n"}')" '{"hostPath":"/etc","pod":"suspect-pod","privileged":"true"}'

# Kubernetes Events As A Short-Lived Signal
page=course-01-kubernetes-events-as-a-short-lived-signal.md
events="$(kubectl -n starfleet get events --field-selector involvedObject.name=suspect-pod --sort-by=.lastTimestamp)"
printf '%s\n' "$events"
# The page names a FROM column; the default output of kubectl get events has
# no such column (it has LAST SEEN, TYPE, REASON, OBJECT and MESSAGE), so it
# is not checked.
for reason in Scheduled Pulled Created Started; do
  expect_match "suspect-pod has a Normal $reason event" "$events" "Normal +$reason +pod/suspect-pod "
done
expect_equal 'all suspect-pod events have the type Normal' "$(printf '%s\n' "$events" | sed 1d | grep -cv ' Normal ' || true)" 0
expect_equal 'Scheduled comes first in time order' "$(printf '%s\n' "$events" | sed 1d | head -n 1 | awk '{print $3}')" Scheduled
# Warning events may or may not exist (a probe Pod can report Unhealthy while
# it starts), so only the command itself is checked.
kubectl -n starfleet get events --field-selector type=Warning

# Reading A Pod Specification For Risky Settings
page=course-02-reading-a-pod-specification-for-risky-settings.md
expect_equal 'the first command prints true' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].securityContext.privileged}{"\n"}')" true
expect_equal 'the second command prints /etc' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.volumes[*].hostPath.path}{"\n"}')" /etc
expect_equal 'the hostPath volume is mounted readOnly' "$(kubectl -n starfleet get pod suspect-pod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="node-config")].readOnly}')" true
privileged_columns="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged)"
printf '%s\n' "$privileged_columns"
expect_match 'suspect-pod shows true' "$privileged_columns" '^starfleet +suspect-pod +true$'
expect_match 'shuttle shows <none>' "$privileged_columns" '^starfleet +shuttle +<none>$'
hostpath_columns="$(kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,HOSTPATH:.spec.volumes[*].hostPath.path)"
printf '%s\n' "$hostpath_columns"
expect_match 'suspect-pod shows /etc' "$hostpath_columns" '^suspect-pod +/etc$'
expect_equal 'only suspect-pod shows a host path; other Pods show <none>' "$(printf '%s\n' "$hostpath_columns" | sed 1d | grep -cv '<none>$' || true)" 1
expect_equal 'starfleet has no pod-security enforce label' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" ''

# Application Log Signals Of Abuse
page=course-03-application-log-signals-of-abuse.md
expect_equal 'grep -c counts 5 failed logins' "$(kubectl -n starfleet logs login-service | grep -c "login failed")" 5
expect_equal 'five failures for admin come first, then one success for ops' "$(kubectl -n starfleet logs login-service)" "$(printf 'login failed user=admin\n%.0s' 1 2 3 4 5; printf 'login ok user=ops')"
timestamped="$(kubectl -n starfleet logs login-service --timestamps)"
printf '%s\n' "$timestamped"
expect_equal 'every one of the six lines starts with a timestamp' "$(printf '%s\n' "$timestamped" | grep -cE "^$timestamp login (failed user=admin|ok user=ops)\$" || true)" 6

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
