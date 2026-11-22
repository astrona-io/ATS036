#!/usr/bin/env bash
# Runs the commands that the module pages teach against the playground cluster
# and fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages show no command output, so each check tests
# the fact that the prose around the command states. Node commands run in the
# kind node container of this playground only.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-040-03}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-036-playground-040-03}"
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
node="$cluster-control-plane"

# Write the YAML block that follows "Save this as `<file>`" on a page.
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

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
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

# After rollout status, the old probe Pods can still be terminating: the Python
# server is process 1 and does not handle SIGTERM, so each old Pod waits for
# its grace period. Wait until only the two new Pods are left, at most about
# 2 minutes, so that exec deploy/probe reaches a new Pod.
wait_for_new_probe_pods_only() {
  local attempt count=''
  for attempt in $(seq 1 60); do
    count="$(kubectl -n starfleet get pods -l app=probe --no-headers | grep -c . || true)"
    [[ "$count" == 2 ]] && return 0
    sleep 2
  done
  printf 'old probe Pods did not go away (%s Pods)\n' "$count" >&2
  kubectl -n starfleet get pods -l app=probe >&2
  exit 1
}

# Print the template value of VERSION and readOnlyRootFilesystem of probe.
probe_template() {
  kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value} {.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'
}

# The playground guide says that probe starts at v1 with a writable root
# filesystem. The module pages change it before the guide runs, so record the
# starting template here and check it in the guide section.
starting_template="$(probe_template)"

# Volumes that reach the host
page=course-01-volumes-that-reach-the-host.md
# The page selects the cluster with astrona kubeconfig. The CI script has
# already set KUBECONFIG, so only the context is checked.
expect_equal 'the playground context is selected' "$(kubectl config current-context)" "$context"
save_yaml_from_page "$page" host-writer.yaml
kubectl apply -f host-writer.yaml
kubectl -n starfleet wait --for=condition=Ready pod/host-writer --timeout=90s
expect_equal 'host-writer writes through the hostPath mount' "$(kubectl -n starfleet exec host-writer -- sh -c 'echo written-by-pod > /node-logs/pod-write-test && cat /node-logs/pod-write-test')" written-by-pod
expect_equal 'host-writer runs on the playground node' "$(kubectl -n starfleet get pod host-writer -o jsonpath='{.spec.nodeName}')" "$node"
expect_equal 'the file exists in /var/log on the node' "$("$engine" exec "$node" cat /var/log/pod-write-test)" written-by-pod
save_yaml_from_page "$page" host-reader.yaml
kubectl apply -f host-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/host-reader --timeout=90s
expect_equal 'host-reader reads the file' "$(kubectl -n starfleet exec host-reader -- cat /node-logs/pod-write-test)" written-by-pod
read_only_write="$(expect_failure kubectl -n starfleet exec host-reader -- sh -c 'echo changed > /node-logs/pod-write-test')"
expect 'host-reader write fails with Read-only file system' "$read_only_write" 'Read-only file system'
kubectl -n starfleet exec host-writer -- rm /node-logs/pod-write-test
expect_equal 'the test file is gone from the node' "$("$engine" exec "$node" sh -c 'test -e /var/log/pod-write-test && echo present || echo absent')" absent

# Updating by replacement
page=course-02-updating-by-replacement.md
kubectl -n starfleet exec deploy/probe -- touch /tmp/manual-change
expect 'the listing shows manual-change' "$(kubectl -n starfleet exec deploy/probe -- ls /tmp)" manual-change
old_pods="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[*].metadata.name}')"
kubectl -n starfleet set env deployment/probe VERSION=v2
kubectl -n starfleet rollout status deployment/probe --timeout=120s
wait_for_new_probe_pods_only
new_pods="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[*].metadata.name}')"
kubectl -n starfleet get pods -l app=probe
for pod in $old_pods; do
  [[ " $new_pods " == *" $pod "* ]] && listed=yes || listed=no
  expect_equal "the old Pod $pod is no longer listed" "$listed" no
done
replica_sets="$(kubectl -n starfleet get replicaset -l app=probe --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.spec.replicas}{"\n"}{end}')"
kubectl -n starfleet get replicaset -l app=probe
expect_equal 'the newest ReplicaSet has two Pods' "$(printf '%s\n' "$replica_sets" | tail -1)" 2
expect_equal 'the older ReplicaSet is scaled to zero' "$(printf '%s\n' "$replica_sets" | head -1)" 0
tmp_listing="$(kubectl -n starfleet exec deploy/probe -- ls /tmp)"
[[ "$tmp_listing" == *manual-change* ]] && manual=present || manual=absent
expect_equal 'the new Pod has no manual-change' "$manual" absent
expect 'the Service answers with version=v2' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe/ready)" 'version=v2'
save_yaml_from_page "$page" probe-patch.yaml
kubectl -n starfleet patch deployment probe --patch-file probe-patch.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=120s
wait_for_new_probe_pods_only
root_write="$(expect_failure kubectl -n starfleet exec deploy/probe -- sh -c 'echo denied > /root-file')"
expect 'writing /root-file fails with Read-only file system' "$root_write" 'Read-only file system'
expect_equal 'writing /tmp works' "$(kubectl -n starfleet exec deploy/probe -- sh -c 'printf ok > /tmp/check; cat /tmp/check')" ok
history="$(kubectl -n starfleet rollout history deployment/probe)"
printf '%s\n' "$history"
expect 'history has a REVISION column' "$history" REVISION
expect_equal 'history lists three revisions' "$(printf '%s\n' "$history" | grep -cE '^[0-9]+ ')" 3
kubectl -n starfleet rollout undo deployment/probe
kubectl -n starfleet rollout status deployment/probe --timeout=120s
expect_equal 'rollback returns to the v2 template without a read-only root' "$(probe_template)" 'v2 '
wait_for_new_probe_pods_only
kubectl -n starfleet patch deployment probe --patch-file probe-patch.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=120s
expect_equal 'the patch makes the root filesystem read-only again' "$(probe_template)" 'v2 true'
wait_for_new_probe_pods_only

# Pinning images and detecting drift
page=course-03-pinning-images-and-detecting-drift.md
images="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}')"
printf '%s\n' "$images"
expect_equal 'one line per probe Pod' "$(printf '%s\n' "$images" | grep -c .)" 2
expect_equal 'each line shows the tag from the template' "$(printf '%s\n' "$images" | awk -F '\t' '{print $2}' | sort -u)" docker.io/library/python:3.13-alpine
expect_equal 'each imageID holds a sha256 digest' "$(printf '%s\n' "$images" | awk -F '\t' '$3 ~ /sha256:[0-9a-f]{64}$/' | grep -c .)" 2
expect_equal 'both probe Pods show the same digest' "$(printf '%s\n' "$images" | awk -F '\t' '{print $3}' | sort -u | grep -c .)" 1
probe_digest="$(printf '%s\n' "$images" | awk -F '\t' 'NR == 1 {print $3}')"
digests="$(kubectl -n starfleet get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[*].imageID}{"\n"}{end}' | sort -u)"
printf '%s\n' "$digests"
expect 'the distinct digests include the probe digest' "$digests" "$probe_digest"
expect_equal 'every distinct line is a digest' "$(printf '%s\n' "$digests" | grep -vc 'sha256:' || true)" 0
kubectl -n starfleet get deployment probe -o yaml > probe-live.yaml
diff_status=0
live_diff="$(kubectl diff -f probe-live.yaml 2>&1)" || diff_status=$?
printf '%s\n' "$live_diff"
# kubectl diff exits 0 for no change and 1 for changes; any other status is an error.
[[ "$diff_status" == 0 || "$diff_status" == 1 ]] && diff_result=ran || diff_result="exit $diff_status"
expect_equal 'kubectl diff compares the live file' "$diff_result" ran
expect_equal 'the diff changes no image, securityContext or volume' "$(printf '%s\n' "$live_diff" | grep -cE '^[-+] +(- )?(image|readOnlyRootFilesystem|emptyDir|hostPath|mountPath):' || true)" 0

# Playground guide
guide=playground/docs/overview.md
# The guide sets KUBECONFIG with astrona kubeconfig and tests the context name.
expect_equal 'guide: the playground context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'guide: probe started at v1 with a writable root filesystem' "$starting_template" 'v1 '
expect 'guide: the Deployment prints as YAML' "$(kubectl -n starfleet get deployment probe -o yaml)" 'kind: Deployment'
expect_equal 'guide: two probe Pods run' "$(kubectl -n starfleet get pods -l app=probe --no-headers | grep -c Running)" 2
save_yaml_from_page "$guide" deployment-probe.yaml
kubectl apply -f deployment-probe.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=180s
wait_for_new_probe_pods_only
expect_equal 'guide: two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect 'guide: the Service answers with version=v2' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe/ready)" 'version=v2'
expect_equal 'guide: writing /tmp works' "$(kubectl -n starfleet exec deploy/probe -- sh -c 'printf ok > /tmp/scratch-check; cat /tmp/scratch-check')" ok
guide_root_write="$(expect_failure kubectl -n starfleet exec deploy/probe -- sh -c 'printf denied > /root-file')"
expect 'guide: writing /root-file fails' "$guide_root_write" 'Read-only file system'
expect_equal 'guide: no hostPath volume in probe' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.volumes[*].hostPath}')" ''

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
