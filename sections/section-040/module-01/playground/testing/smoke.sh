#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# page order, against the live playground, and fails when one of them does not
# give the result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages start with
# `export KUBECONFIG="$(astrona kubeconfig ...)"`; the runner has already done
# that, so the script skips it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-040-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages apply their files from the current directory.
cd "$work_directory"

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

# Run a command that the page shows as failing. Print its output and exit
# status, and fail when it succeeds.
run_failing() {
  local output status=0
  output="$("$@" 2>&1)" || status=$?
  printf '%s\n' "$output"
  if [[ "$status" -eq 0 ]]; then
    printf 'FAIL: the command was expected to fail: %s\n' "$*" >&2
    exit 1
  fi
}

# Retry a command until its output holds the wanted text, at most about 2
# minutes, as the page says to do while the new Pod starts.
wait_for_output() {
  local wanted="$1" output='' attempt
  shift
  for attempt in $(seq 1 40); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# The writable container layer
page=course-01-the-writable-container-layer.md
probe_pod="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')"
echo "$probe_pod"
expect 'a probe Pod name is printed' "$probe_pod" probe-
expect_equal 'the new program runs' "$(kubectl -n starfleet exec "$probe_pod" -- sh -c 'printf "#!/bin/sh\necho added-at-runtime\n" > /usr/local/bin/tool.sh && chmod +x /usr/local/bin/tool.sh && /usr/local/bin/tool.sh')" added-at-runtime
kubectl -n starfleet delete pod "$probe_pod"
new_pod="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')"
missing="$(wait_for_output 'No such file or directory' kubectl -n starfleet exec "$new_pod" -- ls /usr/local/bin/tool.sh)"
expect 'tool.sh is not in the replacement Pod' "$missing" 'No such file or directory'
kubectl -n starfleet rollout status deployment/probe --timeout=180s
image_id="$(kubectl -n starfleet get pod "$new_pod" -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}')"
printf '%s\n' "$image_id"
checks=$((checks + 1))
printf 'check: %s\n' 'imageID is sha256: and 64 hexadecimal characters'
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || { printf 'FAIL: imageID has another form: %s\n' "$image_id" >&2; exit 1; }

# Read-only root filesystem and security context
page=course-02-read-only-root-filesystem-and-security-context.md
expect_equal 'current context is the playground' "$(kubectl config current-context)" "$context"
expect_equal 'shuttle uses the BusyBox image' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.containers[0].image}{"\n"}')" docker.io/library/busybox:1.37.0
save_yaml_from_page "$page" sealed-reader.yaml
kubectl apply -f sealed-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/sealed-reader --timeout=90s
root_write="$(run_failing kubectl -n starfleet exec sealed-reader -- sh -c 'echo test > /root-file')"
expect 'root filesystem write fails as read-only' "$root_write" 'Read-only file system'
expect_equal 'scratch write prints test' "$(kubectl -n starfleet exec sealed-reader -- sh -c 'echo test > /scratch/file && cat /scratch/file')" test
identity="$(kubectl -n starfleet exec sealed-reader -- id)"
printf '%s\n' "$identity"
expect 'id shows user 10001' "$identity" 'uid=10001'
expect 'id shows group 10001' "$identity" 'gid=10001'
status_lines="$(kubectl -n starfleet exec sealed-reader -- grep -E 'CapEff|NoNewPrivs' /proc/1/status)"
printf '%s\n' "$status_lines"
expect 'CapEff is all zeros' "$status_lines" $'CapEff:\t0000000000000000'
expect 'NoNewPrivs is 1' "$status_lines" $'NoNewPrivs:\t1'
stored="$(kubectl -n starfleet get pod sealed-reader -o jsonpath='{.spec.containers[0].securityContext}{"\n"}')"
printf '%s\n' "$stored"
expect 'stored readOnlyRootFilesystem is true' "$stored" '"readOnlyRootFilesystem":true'
expect 'stored allowPrivilegeEscalation is false' "$stored" '"allowPrivilegeEscalation":false'
expect 'stored capability drop list' "$stored" '"drop":["ALL"]'

# Limits of a read-only filesystem and Pod Security Admission
page=course-03-limits-of-a-read-only-filesystem-and-pod-security-admission.md
expect_equal 'current context is the playground' "$(kubectl config current-context)" "$context"
kubectl create namespace sealed
kubectl label namespace sealed pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest
save_yaml_from_page "$page" plain-pod.yaml
rejected="$(run_failing kubectl apply -f plain-pod.yaml)"
expect 'plain Pod is forbidden' "$rejected" 'is forbidden'
expect 'message names restricted:latest' "$rejected" 'violates PodSecurity "restricted:latest"'
expect 'message lists allowPrivilegeEscalation' "$rejected" 'allowPrivilegeEscalation != false'
expect 'message lists unrestricted capabilities' "$rejected" 'unrestricted capabilities'
expect 'message lists runAsNonRoot' "$rejected" 'runAsNonRoot != true'
expect 'message lists seccompProfile' "$rejected" 'seccompProfile'
save_yaml_from_page "$page" compliant-pod.yaml
expect 'compliant Pod is accepted' "$(kubectl apply -f compliant-pod.yaml)" 'pod/compliant-pod created'
kubectl -n sealed wait --for=condition=Ready pod/compliant-pod --timeout=90s
expect_equal 'root filesystem of the compliant Pod is writable' "$(kubectl -n sealed exec compliant-pod -- sh -c 'echo test > /root-file && echo written')" written

# Verifying and enforcing immutability
page=course-04-verifying-and-enforcing-immutability.md
expect_equal 'current context is the playground' "$(kubectl config current-context)" "$context"
readonly_columns="$(kubectl get pods -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READONLY:.spec.containers[0].securityContext.readOnlyRootFilesystem')"
printf '%s\n' "$readonly_columns"
expect_equal 'probe, shuttle and drifter show <none>' "$(printf '%s\n' "$readonly_columns" | awk '($2 ~ /^probe-/ || $2 == "shuttle" || $2 == "drifter") {print $3}' | sort -u)" '<none>'
expect_equal 'sealed-reader shows true' "$(printf '%s\n' "$readonly_columns" | awk '$2 == "sealed-reader" {print $3}')" true
expect_equal 'compliant-pod shows <none>' "$(printf '%s\n' "$readonly_columns" | awk '$2 == "compliant-pod" {print $3}')" '<none>'
expect_equal 'kube-system Pods show <none> or true' "$(printf '%s\n' "$readonly_columns" | awk '$1 == "kube-system" && $3 != "<none>" && $3 != "true"' | wc -l | tr -d ' ')" 0
save_yaml_from_page "$page" policy-readonly-root.yaml
save_yaml_from_page "$page" binding-readonly-root.yaml
kubectl apply -f policy-readonly-root.yaml
kubectl apply -f binding-readonly-root.yaml
save_yaml_from_page "$page" writable-pod.yaml
# The page says: if the Pod is accepted, the binding is not active yet; wait a
# few seconds and apply again. An accepted Pod is deleted before the retry,
# because a second apply of an unchanged Pod sends no request.
denied=''
for attempt in $(seq 1 15); do
  status=0
  denied="$(kubectl apply -f writable-pod.yaml 2>&1)" || status=$?
  [[ "$status" -ne 0 ]] && break
  kubectl -n sealed delete pod writable-pod --wait=true
  sleep 3
done
printf '%s\n' "$denied"
expect_equal 'writable Pod is rejected' "$status" 1
expect 'error names the policy require-readonly-root' "$denied" "'require-readonly-root'"
expect 'error shows the policy message' "$denied" 'Every container must set readOnlyRootFilesystem to true.'
# Add readOnlyRootFilesystem: true to the container securityContext, as the
# page says, and apply the file again.
python3 - writable-pod.yaml <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = '      securityContext:\n        allowPrivilegeEscalation: false\n'
assert old in text, 'container securityContext not found'
open(path, 'w').write(text.replace(old, '      securityContext:\n        readOnlyRootFilesystem: true\n        allowPrivilegeEscalation: false\n'))
PY
expect 'Pod with readOnlyRootFilesystem is accepted' "$(kubectl apply -f writable-pod.yaml)" 'pod/writable-pod created'
expect_equal 'outpost default may not exec in starfleet' "$(kubectl auth can-i create pods/exec -n starfleet --as=system:serviceaccount:outpost:default || true)" no
images="$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}')"
printf '%s\n' "$images"
expect_equal 'each line has the tag from the specification' "$(printf '%s\n' "$images" | awk '{print $2}' | sort -u)" docker.io/library/python:3.13-alpine
expect 'each line has the sha256 digest' "$(printf '%s\n' "$images" | awk '{print $3}' | sort -u)" 'sha256:'
expect_equal 'all replicas show the same digest' "$(printf '%s\n' "$images" | awk '{print $3}' | sort -u | wc -l | tr -d ' ')" 1

# Playground guide
guide=playground/docs/overview.md
guide_pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$guide_pods"
expect_equal 'guide: two probe Pods are Running' "$(printf '%s\n' "$guide_pods" | grep -E '^probe-' | grep -c ' Running ')" 2
expect 'guide: shuttle is Running' "$(printf '%s\n' "$guide_pods" | grep -E '^shuttle ')" Running
expect 'guide: probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o yaml)" 'readyReplicas: 2'
save_yaml_from_page "$guide" pod-restricted-reader.yaml
kubectl apply -f pod-restricted-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/restricted-reader --timeout=180s
expect_equal 'guide: process runs as user 1000' "$(kubectl -n starfleet exec restricted-reader -- id -u)" 1000
expect_equal 'guide: scratch write is allowed' "$(kubectl -n starfleet exec restricted-reader -- sh -c 'printf allowed > /scratch/result; cat /scratch/result')" allowed
guide_denied="$(run_failing kubectl -n starfleet exec restricted-reader -- sh -c 'printf denied > /root-file')"
expect 'guide: root filesystem write is denied' "$guide_denied" 'Read-only file system'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
