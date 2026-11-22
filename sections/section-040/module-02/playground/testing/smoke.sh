#!/usr/bin/env bash
# Runs the commands that the module pages teach against the playground cluster
# and fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster. The pages show no command output, so each check tests
# the fact that the prose around the command states.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-036-playground-040-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages apply the saved files by their bare names.
cd "$work_directory"

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

# Print the value of one /proc/1/status field of a starfleet Pod, for example CapEff.
status_value() {
  kubectl -n starfleet exec "$1" -- grep -E "^$2:" /proc/1/status | awk '{print $2}'
}

# Print "non-zero" when a hexadecimal capability mask has a set bit, else "zero".
mask_kind() {
  [[ "$1" =~ [1-9a-f] ]] && echo non-zero || echo zero
}

# Linux capabilities and what a container starts with
page=course-01-linux-capabilities-and-what-a-container-starts-with.md
# The page selects the cluster with astrona kubeconfig. The CI script has
# already set KUBECONFIG, so only the context is checked.
expect_equal 'the playground context is selected' "$(kubectl config current-context)" "$context"
save_from_page "$page" cap-default.yaml
kubectl -n starfleet wait --for=condition=Ready pod/cap-default --timeout=90s
default_sets="$(kubectl -n starfleet exec cap-default -- grep -E 'CapBnd|CapEff' /proc/1/status)"
printf '%s\n' "$default_sets"
expect_equal 'default container shows CapBnd and CapEff' "$(printf '%s\n' "$default_sets" | grep -cE '^Cap(Bnd|Eff):')" 2
expect_equal 'default CapBnd is non-zero' "$(mask_kind "$(status_value cap-default CapBnd)")" non-zero
expect_equal 'default CapEff is non-zero' "$(mask_kind "$(status_value cap-default CapEff)")" non-zero
save_yaml_from_page "$page" cap-dropped.yaml
kubectl apply -f cap-dropped.yaml
kubectl -n starfleet wait --for=condition=Ready pod/cap-dropped --timeout=90s
kubectl -n starfleet exec cap-dropped -- grep -E 'CapBnd|CapEff' /proc/1/status
expect_equal 'dropped CapBnd is all zeros' "$(status_value cap-dropped CapBnd)" 0000000000000000
expect_equal 'dropped CapEff is all zeros' "$(status_value cap-dropped CapEff)" 0000000000000000
expect_equal 'chown works in the default container' "$(kubectl -n starfleet exec cap-default -- sh -c 'touch /tmp/owned && chown 1234 /tmp/owned && echo changed')" changed
if denied="$(kubectl -n starfleet exec cap-dropped -- sh -c 'touch /tmp/owned && chown 1234 /tmp/owned && echo changed' 2>&1)"; then
  printf 'FAIL: chown without CHOWN unexpectedly succeeded\n%s\n' "$denied" >&2
  exit 1
fi
expect 'chown without CHOWN fails with Operation not permitted' "$denied" 'Operation not permitted'

# Non-root identity and privilege escalation
page=course-02-non-root-identity-and-privilege-escalation.md
save_yaml_from_page "$page" root-refused.yaml
kubectl apply -f root-refused.yaml
refused_status=''
for attempt in $(seq 1 45); do
  refused_status="$(kubectl -n starfleet get pod root-refused --no-headers | awk '{print $3}')"
  [[ "$refused_status" == CreateContainerConfigError ]] && break
  sleep 2
done
kubectl -n starfleet get pod root-refused
expect_equal 'root-refused has status CreateContainerConfigError' "$refused_status" CreateContainerConfigError
expect 'the event says runAsNonRoot and image will run as root' "$(kubectl -n starfleet describe pod root-refused)" 'container has runAsNonRoot and image will run as root'
kubectl -n starfleet delete pod root-refused
save_yaml_from_page "$page" non-root.yaml
kubectl apply -f non-root.yaml
kubectl -n starfleet wait --for=condition=Ready pod/non-root --timeout=90s
identity="$(kubectl -n starfleet exec non-root -- id)"
printf '%s\n' "$identity"
expect 'non-root runs as user 2000' "$identity" 'uid=2000'
expect 'non-root runs as group 2000' "$identity" 'gid=2000'
save_yaml_from_page "$page" no-escalation.yaml
kubectl apply -f no-escalation.yaml
kubectl -n starfleet wait --for=condition=Ready pod/no-escalation --timeout=90s
expect_equal 'non-root shows NoNewPrivs 0' "$(kubectl -n starfleet exec non-root -- grep NoNewPrivs /proc/1/status | awk '{print $2}')" 0
expect_equal 'no-escalation shows NoNewPrivs 1' "$(kubectl -n starfleet exec no-escalation -- grep NoNewPrivs /proc/1/status | awk '{print $2}')" 1
# grep Seccomp also matches Seccomp_filters, so take the Seccomp line only.
expect_equal 'no-escalation shows Seccomp 2' "$(kubectl -n starfleet exec no-escalation -- grep Seccomp /proc/1/status | awk '$1 == "Seccomp:" {print $2}')" 2

# Privileged containers and verifying process privileges
page=course-03-privileged-containers-and-verifying-process-privileges.md
review="$(kubectl get pods -A -o custom-columns='NAMESPACE:.metadata.namespace,POD:.metadata.name,PRIVILEGED:.spec.containers[*].securityContext.privileged,ESCALATION:.spec.containers[*].securityContext.allowPrivilegeEscalation,ADDED:.spec.containers[*].securityContext.capabilities.add')"
printf '%s\n' "$review"
expect 'review has the PRIVILEGED column' "$(printf '%s\n' "$review" | head -1)" PRIVILEGED
expect 'kube-proxy, a system Pod, shows true in PRIVILEGED' "$(printf '%s\n' "$review" | grep -E '^kube-system +kube-proxy-' | head -1)" true
expect_equal 'no-escalation shows false in ESCALATION' "$(printf '%s\n' "$review" | awk '$1 == "starfleet" && $2 == "no-escalation" {print $4}')" false
expect_equal 'no starfleet Pod is privileged' "$(printf '%s\n' "$review" | awk '$1 == "starfleet" && $3 == "true"' | grep -c . || true)" 0
expect 'outpost gets the enforce label' "$(kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline)" 'namespace/outpost labeled'
save_yaml_from_page "$page" privileged-pod.yaml
if rejected="$(kubectl apply -f privileged-pod.yaml 2>&1)"; then
  printf 'FAIL: privileged Pod was admitted\n%s\n' "$rejected" >&2
  exit 1
fi
printf '%s\n' "$rejected"
expect 'rejection names the baseline standard' "$rejected" 'violates PodSecurity "baseline'
expect 'rejection names the privileged field of the container' "$rejected" 'privileged (container "worker" must not set securityContext.privileged=true)'
expect_equal 'privileged-pod was not created' "$(kubectl -n outpost get pod privileged-pod --ignore-not-found -o name)" ''
expect_equal 'drifter keeps running under the label' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running
expect 'outpost loses the enforce label' "$(kubectl label namespace outpost pod-security.kubernetes.io/enforce-)" 'namespace/outpost unlabeled'
uid="$(kubectl -n starfleet exec no-escalation -- id -u)"
printf '%s\n' "$uid"
[[ "$uid" =~ ^[0-9]+$ && "$uid" != 0 ]] && uid_kind=non-zero || uid_kind="$uid"
expect_equal 'no-escalation user ID is non-zero' "$uid_kind" non-zero
kubectl -n starfleet exec no-escalation -- grep -E 'CapEff|NoNewPrivs' /proc/1/status
expect_equal 'no-escalation CapEff is all zeros' "$(status_value no-escalation CapEff)" 0000000000000000
expect_equal 'no-escalation NoNewPrivs is 1' "$(status_value no-escalation NoNewPrivs)" 1

# Playground guide
guide=playground/docs/overview.md
# The guide sets KUBECONFIG with astrona kubeconfig and tests the context name.
expect_equal 'guide: the playground context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$pods"
expect 'guide: shuttle is Running' "$(printf '%s\n' "$pods" | grep -E '^shuttle ')" Running
expect_equal 'guide: both probe Pods are Running' "$(printf '%s\n' "$pods" | grep -E '^probe-' | grep -c Running)" 2
expect_equal 'guide: shuttle container has no securityContext' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.containers[0].securityContext}{"\n"}')" ''
save_yaml_from_page "$guide" pod-capability-free.yaml
kubectl apply -f pod-capability-free.yaml
kubectl -n starfleet wait --for=condition=Ready pod/capability-free --timeout=180s
expect_equal 'guide: capability-free runs as user 2000' "$(kubectl -n starfleet exec capability-free -- id -u)" 2000
expect_equal 'guide: capability-free CapEff is all zeros' "$(kubectl -n starfleet exec capability-free -- sh -c "awk '/^CapEff/ {print \$2}' /proc/1/status")" 0000000000000000
expect_equal 'guide: capability-free CapBnd is all zeros' "$(kubectl -n starfleet exec capability-free -- sh -c "awk '/^CapBnd/ {print \$2}' /proc/1/status")" 0000000000000000
expect_equal 'guide: capability-free NoNewPrivs is 1' "$(kubectl -n starfleet exec capability-free -- sh -c "awk '/^NoNewPrivs/ {print \$2}' /proc/1/status")" 1
expect_equal 'guide: capability-free stays Running' "$(kubectl -n starfleet get pod capability-free -o jsonpath='{.status.phase}')" Running

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
