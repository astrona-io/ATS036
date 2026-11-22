#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages start with
# `export KUBECONFIG="$(astrona kubeconfig ...)"`; the runner has already done
# that, so the script skips it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-020-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
reporter=system:serviceaccount:starfleet:reporter
auditor=system:serviceaccount:starfleet:auditor

# Write the YAML block that follows "Save this as `<file>`" (or "as `<file>`") on a page.
save_yaml_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no YAML block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_yaml_from_page "$1" "$2"
  kubectl apply -f "$work_directory/$2"
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

# ServiceAccounts and user identity
page=course-01-serviceaccounts-and-user-identity.md
accounts="$(kubectl -n starfleet get serviceaccounts)"
printf '%s\n' "$accounts"
expect_equal 'list has default, auditor and reporter' "$(printf '%s\n' "$accounts" | awk 'NR > 1 {print $1}' | sort | tr '\n' ' ')" 'auditor default reporter '
expect_equal 'data-client uses reporter' "$(kubectl -n starfleet get pod data-client -o jsonpath='{.spec.serviceAccountName}{"\n"}')" reporter
expect_equal 'token volume holds ca.crt, namespace and token' "$(kubectl -n starfleet exec data-client -- ls /var/run/secrets/kubernetes.io/serviceaccount | tr '\n' ' ')" 'ca.crt namespace token '
automount="$(kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken)"
printf '%s\n' "$automount"
expect_equal 'AUTOMOUNT is <none> for every Pod' "$(printf '%s\n' "$automount" | awk 'NR > 1 && $3 != "<none>"' | wc -l | tr -d ' ')" 0
expect 'data-client row names reporter' "$(printf '%s\n' "$automount" | grep -E '^data-client ')" reporter

# Who can read Secrets
page=course-02-who-can-read-secrets.md
expect_equal 'reporter may get Secrets' "$(kubectl auth can-i get secrets -n starfleet --as="$reporter")" yes
status=0
answer="$(kubectl auth can-i get secrets -n starfleet --as="$auditor")" || status=$?
expect_equal 'auditor may not get Secrets' "$answer" no
expect_equal 'the no answer exits with status 1' "$status" 1
review="$(kubectl auth can-i --list -n starfleet --as="$auditor")"
printf '%s\n' "$review"
expect 'review holds the pod-reader rule' "$(printf '%s\n' "$review" | grep -E '^pods ')" '[get list]'
expect_equal 'review has no Secret rule' "$(printf '%s\n' "$review" | grep -cE '^secrets ' || true)" 0
bindings="$(kubectl -n starfleet get rolebindings -o wide)"
printf '%s\n' "$bindings"
reporter_row="$(printf '%s\n' "$bindings" | grep -E '^reporter-secrets ')"
expect 'reporter-secrets uses Role secret-reader' "$reporter_row" Role/secret-reader
expect 'reporter-secrets names starfleet/reporter' "$reporter_row" starfleet/reporter
# The page only lists the cluster-wide bindings and describes no row.
expect 'cluster-wide bindings are listed' "$(kubectl get clusterrolebindings -o wide)" ClusterRole/cluster-admin

# Secret exposure paths
page=course-03-secret-exposure-paths.md
expect_equal 'first command prints the encoded value' "$(kubectl -n starfleet get secret db-credentials -o jsonpath='{.data.password}{"\n"}')" "$(printf 'pass-1234' | base64)"
expect_equal 'second command prints pass-1234' "$(kubectl -n starfleet get secret db-credentials -o jsonpath='{.data.password}' | base64 -d)" pass-1234
expect_equal 'data-client references db-credentials' "$(kubectl -n starfleet get pod data-client -o jsonpath='{.spec.containers[0].env[0].valueFrom.secretKeyRef.name}{"\n"}')" db-credentials
expect_equal 'printenv shows the decoded value' "$(kubectl -n starfleet exec data-client -- printenv DB_PASSWORD)" pass-1234
secret_users="$(kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SECRETENV:.spec.containers[*].env[*].valueFrom.secretKeyRef.name)"
printf '%s\n' "$secret_users"
expect_equal 'only data-client shows db-credentials' "$(printf '%s\n' "$secret_users" | awk '/db-credentials/ {print $1}')" data-client

# Playground guide
guide=playground/docs/overview.md
expect_equal 'guide: reporter may get Secrets' "$(kubectl auth can-i get secrets -n starfleet --as="$reporter")" yes
expect_equal 'guide: auditor may not get Secrets' "$(kubectl auth can-i get secrets -n starfleet --as="$auditor" || true)" no
expect 'guide: bindings name reporter-secrets' "$(kubectl -n starfleet get rolebindings -o wide | grep -E '^reporter-secrets ')" Role/secret-reader
save_from_page "$guide" configmap-access-finding.yaml
expect_equal 'guide: reporter still may get Secrets' "$(kubectl auth can-i get secrets -n starfleet --as="$reporter")" yes
finding="$(kubectl -n starfleet get configmap access-finding -o jsonpath='{.data}{"\n"}')"
printf '%s\n' "$finding"
expect 'guide: finding names the binding' "$finding" '"binding":"reporter-secrets"'
expect 'guide: finding names the subject' "$finding" "\"subject\":\"$reporter\""
expect 'guide: finding names the verb' "$finding" '"verb":"get"'
expect 'guide: finding names the resource' "$finding" '"resource":"secrets"'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
