#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-036-playground-010-02
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
# No page of this module runs a node command in the kind playground, so
# "$engine" and "$cluster" are only part of the shared guard settings.

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

# Write the YAML block from a page and apply it, as "Apply it:" does.
save_from_page() {
  save_file_from_page "$1" "$2"
  kubectl apply -f "$2"
}

# Print the text block that follows a sentence on a page.
text_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, sentence = sys.argv[1:]
text = open(page).read()
match = re.search(re.escape(sentence) + r'.*?```text\n(.*?)```', text, re.S)
if not match:
    sys.exit('no text block after "' + sentence + '" in ' + page)
sys.stdout.write(match.group(1))
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

# Print the rules.yaml text of a saved ConfigMap file, without the final
# newline, as the jsonpath command prints it inside $(...).
rules_from_file() {
  python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["data"]["rules.yaml"].rstrip("\n"))' "$1"
}

# Guided Practice: Write A Scoped Shell Detection Rule
# The guide opens with the playground and describes the starting state, so it
# runs first.
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c ' Running ' || true)" 2
expect_match 'guide: the shuttle client Pod is Running' "$pods" '^shuttle +1/1 +Running '
configmaps="$(kubectl -n starfleet get configmaps)"
printf '%s\n' "$configmaps"
expect_equal 'guide: no detection rule is stored yet' "$(printf '%s\n' "$configmaps" | grep -c '^shell-in-probe-rule ' || true)" 0
expect 'guide: apply creates the rule ConfigMap' "$(save_from_page "$page" configmap-shell-rule.yaml)" 'configmap/shell-in-probe-rule created'
stored="$(kubectl -n starfleet get configmap shell-in-probe-rule -o jsonpath='{.data.rules\.yaml}')"
printf '%s\n' "$stored"
expect_equal 'guide: the stored rule is the saved rule text' "$stored" "$(rules_from_file configmap-shell-rule.yaml)"
expect 'guide: the stored rule has a condition' "$stored" 'condition: >'
expect 'guide: the stored rule has an output' "$stored" 'output: >'
expect 'guide: the stored rule has priority WARNING' "$stored" 'priority: WARNING'
expect_match 'guide: the probe Deployment is unchanged with 2/2 ready' "$(kubectl -n starfleet get deployment probe)" '^probe +2/2 '

# Anatomy Of A Falco Rule File
page=course-01-anatomy-of-a-falco-rule-file.md
expect_equal 'the context is kind-astro-ats-036-playground-010-02' "$(kubectl config current-context)" "$context"
processes="$(kubectl -n starfleet exec deploy/probe -- ps)"
printf '%s\n' "$processes"
expect_match 'process 1 is python /app/server.py' "$processes" '^ *1 +[a-z]+ +[0-9:]+ python /app/server.py$'
expect_match 'the ps command is listed' "$processes" ' ps$'
labels="$(kubectl get pods -A --show-labels)"
printf '%s\n' "$labels"
expect_match 'probe Pods carry the app=probe label in starfleet' "$labels" '^starfleet +probe-.* app=probe,'
expect_match 'drifter carries app=drifter in outpost' "$labels" '^outpost +drifter .* app=drifter$'

# Scope A Shell Rule To A Namespace
page=course-02-scope-a-shell-rule-to-a-namespace.md
# The guide stored the same object, so the apply of this page reports it.
expect 'apply stores the rule ConfigMap' "$(save_from_page "$page" configmap-shell-rule.yaml)" 'configmap/shell-in-probe-rule'
stored="$(kubectl -n starfleet get configmap shell-in-probe-rule -o jsonpath='{.data.rules\.yaml}')"
printf '%s\n' "$stored"
expect_equal 'the command prints the rule text exactly as stored' "$stored" "$(rules_from_file configmap-shell-rule.yaml)"
# The stored condition is the complete condition that the page builds.
stored_condition="$(printf '%s\n' "$stored" | python3 -c 'import sys, yaml; print(" ".join(yaml.safe_load(sys.stdin)[0]["condition"].split()))')"
page_condition="$(text_from_page "$page" 'The complete condition is:' | tr '\n' ' ' | sed 's/ *$//')"
expect_equal 'the stored condition is the complete condition on the page' "$stored_condition" "$page_condition"

# Exceptions, Testing And Limits Of A Rule
# The page shows an exceptions block to read and runs no command.

# Test A Live Sensor In A Linux VM
# Join A Runtime Event To Kubernetes Identity
# Both pages run in the VM of their own graded lab (`astrona ssh`, Falco,
# systemd and Helm in that VM), not in this kind playground, so this script
# skips their commands.

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
