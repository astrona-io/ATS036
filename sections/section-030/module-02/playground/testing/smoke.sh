#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages start with
# `export KUBECONFIG="$(astrona kubeconfig ...)"`; the runner has already done
# that, so the script skips it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-030-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages write their files to the current directory.
cd "$work_directory"
build_helper=system:serviceaccount:starfleet:build-helper
probe_reader=system:serviceaccount:starfleet:probe-reader

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

# Print the answer of kubectl auth can-i; "no" exits with status 1.
can_i() {
  kubectl -n starfleet auth can-i "$@" || true
}

# Wait until no cache-sync Pod is left, at most about 2 minutes.
wait_for_no_cache_sync_pods() {
  local attempt
  for attempt in $(seq 1 60); do
    [[ -z "$(kubectl -n starfleet get pods -l app=cache-sync -o name)" ]] && return 0
    sleep 2
  done
  printf 'cache-sync Pods are still there\n' >&2
  exit 1
}

# Persistence in workload templates and schedules
page=course-01-persistence-in-workload-templates-and-schedules.md
expect_equal 'current context is the playground' "$(kubectl config current-context)" "$context"
first_pods="$(kubectl -n starfleet get pods -l app=cache-sync)"
printf '%s\n' "$first_pods"
expect_equal 'one cache-sync Pod is Running' "$(printf '%s\n' "$first_pods" | grep -E '^cache-sync-' | grep -c ' Running ')" 1
first_pod="$(printf '%s\n' "$first_pods" | awk '/^cache-sync-/ {print $1}')"
pod_owner="$(kubectl -n starfleet get pods -l app=cache-sync -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{" "}{.items[0].metadata.ownerReferences[0].name}{"\n"}')"
printf '%s\n' "$pod_owner"
expect 'Pod owner is a cache-sync ReplicaSet' "$pod_owner" 'ReplicaSet cache-sync-'
replica_set="$(kubectl -n starfleet get pods -l app=cache-sync -o jsonpath='{.items[0].metadata.ownerReferences[0].name}')"
expect_equal 'ReplicaSet owner is Deployment cache-sync' "$(kubectl -n starfleet get replicaset "$replica_set" -o jsonpath='{.metadata.ownerReferences[0].kind}{" "}{.metadata.ownerReferences[0].name}{"\n"}')" 'Deployment cache-sync'
template="$(kubectl -n starfleet get deployment cache-sync -o yaml)"
expect 'template names the ServiceAccount' "$template" 'serviceAccountName: build-helper'
expect 'template names the image' "$template" 'image: docker.io/library/busybox:1.37.0'
expect 'template has the command' "$template" 'echo "syncing to $UPSTREAM"; sleep 3600'
expect 'template has the env list' "$template" 'name: UPSTREAM'
expect 'Deployment has a creation time' "$template" 'creationTimestamp: '
# The page also says to check metadata.managedFields in this output.
# kubectl get -o yaml leaves managedFields out unless --show-managed-fields is
# given, so the script does not check it.
# The page says the combined command prints an error here, because the
# playground has no StatefulSet or CronJob, and to run one kind at a time.
if workloads="$(kubectl get deployments,daemonsets,statefulsets,cronjobs -A --sort-by=.metadata.creationTimestamp 2>&1)"; then
  printf 'FAIL: the combined sorted list did not fail as the page says\n' >&2; exit 1
fi
printf '%s\n' "$workloads"
expect 'combined command prints the sort error' "$workloads" "couldn't find any field with path \"{.metadata.creationTimestamp}\" in the list of objects"
workloads="$(kubectl get deployments -A --sort-by=.metadata.creationTimestamp)"
printf '%s\n' "$workloads"
expect 'newest Deployment, cache-sync, appears last' "$(printf '%s\n' "$workloads" | tail -1)" 'cache-sync'
kubectl -n starfleet delete pod -l app=cache-sync
second_pods="$(kubectl -n starfleet get pods -l app=cache-sync)"
printf '%s\n' "$second_pods"
expect_equal 'listing shows one replacement Pod' "$(printf '%s\n' "$second_pods" | grep -c '^cache-sync-')" 1
expect_absent 'replacement Pod has a different name' "$second_pods" "$first_pod "
kubectl -n starfleet rollout status deployment/cache-sync --timeout=180s

# Privilege escalation through bindings and Pod settings
page=course-02-privilege-escalation-through-bindings-and-pod-settings.md
bindings="$(kubectl -n starfleet get rolebindings -o wide)"
printf '%s\n' "$bindings"
helper_row="$(printf '%s\n' "$bindings" | grep -E '^build-helper-edit ')"
expect 'build-helper-edit gives ClusterRole edit' "$helper_row" ClusterRole/edit
expect 'build-helper-edit names starfleet/build-helper' "$helper_row" starfleet/build-helper
binding="$(kubectl -n starfleet get rolebinding build-helper-edit -o yaml)"
expect 'roleRef points to ClusterRole edit' "$binding" $'kind: ClusterRole\n  name: edit'
helper_review="$(kubectl -n starfleet auth can-i --list --as="$build_helper")"
expect 'edit may read Secrets' "$(printf '%s\n' "$helper_review" | grep -E '^secrets ')" get
expect 'edit may create Pods' "$(printf '%s\n' "$helper_review" | grep -E '^pods ')" create
expect_equal 'build-helper may get Secrets' "$(can_i get secrets --as="$build_helper")" yes
expect_equal 'build-helper may not create RoleBindings' "$(can_i create rolebindings --as="$build_helper")" no
reader_review="$(kubectl -n starfleet auth can-i --list --as="$probe_reader")"
expect_equal 'view does not list Secrets' "$(printf '%s\n' "$reader_review" | grep -cE '^secrets ' || true)" 0
expect_absent 'view may not create Pods' "$(printf '%s\n' "$reader_review" | grep -E '^pods ')" create
expect_equal 'probe-reader may not get Secrets' "$(can_i get secrets --as="$probe_reader")" no
expect_equal 'probe-reader may not create RoleBindings' "$(can_i create rolebindings --as="$probe_reader")" no
settings="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,HOSTPID:.spec.hostPID,HOSTNETWORK:.spec.hostNetwork)"
printf '%s\n' "$settings"
expect_equal 'cache-sync sets none of the node-level fields' "$(printf '%s\n' "$settings" | awk '$2 ~ /^cache-sync-/ {print $3, $4, $5}')" '<none> <none> <none>'
expect 'some kube-system Pods set hostNetwork' "$(printf '%s\n' "$settings" | awk '$1 == "kube-system" {print $5}' | sort -u)" true
kubectl -n starfleet get deployment cache-sync -o yaml > cache-sync-deployment.yaml
kubectl -n starfleet get rolebinding build-helper-edit -o yaml > build-helper-edit-binding.yaml
kubectl -n starfleet logs -l app=cache-sync --timestamps > cache-sync-logs.txt
expect 'saved Deployment holds the template' "$(cat cache-sync-deployment.yaml)" 'serviceAccountName: build-helper'
expect 'saved binding holds the roleRef' "$(cat build-helper-edit-binding.yaml)" 'name: edit'
expect 'saved log holds the container output' "$(cat cache-sync-logs.txt)" 'syncing to 203.0.113.9'
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit
wait_for_no_cache_sync_pods
contained="$(kubectl -n starfleet get pods,rolebindings 2>&1)"
printf '%s\n' "$contained"
expect_absent 'no cache-sync Pod remains' "$contained" pod/cache-sync-
expect_absent 'build-helper-edit is gone' "$contained" build-helper-edit
expect 'probe-reader-view still exists' "$contained" rolebinding.rbac.authorization.k8s.io/probe-reader-view
expect_equal 'build-helper lost the access at once' "$(can_i get secrets --as="$build_helper")" no

# Playground guide
guide=playground/docs/overview.md
# The guide starts from the starting state ("one replica", "two RoleBindings")
# and repeats the containment that the second page already did. Restore the
# starting state first, so the guide commands run as a learner who opens the
# guide on a fresh playground sees them.
kubectl apply -f "$module_directory/playground/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/cache-sync --timeout=180s
guide_pods="$(kubectl -n starfleet get pods -l app=cache-sync)"
printf '%s\n' "$guide_pods"
expect_equal 'guide: one cache-sync Pod is Running' "$(printf '%s\n' "$guide_pods" | grep -E '^cache-sync-' | grep -c ' Running ')" 1
guide_template="$(kubectl -n starfleet get deployment cache-sync -o yaml)"
expect 'guide: Deployment has one replica' "$guide_template" 'replicas: 1'
expect 'guide: Deployment uses build-helper' "$guide_template" 'serviceAccountName: build-helper'
guide_bindings="$(kubectl -n starfleet get rolebindings -o wide)"
printf '%s\n' "$guide_bindings"
expect_equal 'guide: two RoleBindings' "$(printf '%s\n' "$guide_bindings" | awk 'NR > 1' | wc -l | tr -d ' ')" 2
expect 'guide: build-helper-edit gives ClusterRole edit' "$(printf '%s\n' "$guide_bindings" | grep -E '^build-helper-edit ')" ClusterRole/edit
save_yaml_from_page "$guide" configmap-persistence-finding.yaml
kubectl apply -f configmap-persistence-finding.yaml
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit
wait_for_no_cache_sync_pods
finding="$(kubectl -n starfleet get configmap persistence-finding -o yaml)"
expect 'guide: finding names the Deployment' "$finding" 'deployment: cache-sync'
expect 'guide: finding names the binding' "$finding" 'binding: build-helper-edit'
expect 'guide: finding names the ClusterRole' "$finding" 'clusterRole: edit'
expect 'guide: finding has the finding value' "$finding" 'finding: persistence-and-escalated-authority'
guide_contained="$(kubectl -n starfleet get pods,rolebindings 2>&1)"
printf '%s\n' "$guide_contained"
expect_absent 'guide: no cache-sync Pod remains' "$guide_contained" pod/cache-sync-
expect 'guide: probe-reader-view is still present' "$guide_contained" rolebinding.rbac.authorization.k8s.io/probe-reader-view
expect_absent 'guide: build-helper-edit is gone' "$guide_contained" build-helper-edit
expect_equal 'guide: Deployment still exists with zero replicas' "$(kubectl -n starfleet get deployment cache-sync -o jsonpath='{.spec.replicas}')" 0
expect_equal 'guide: build-helper lost the access at once' "$(can_i get secrets --as="$build_helper")" no

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
