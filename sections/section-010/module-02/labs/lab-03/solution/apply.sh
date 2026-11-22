#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-010-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

sudo tee /etc/falco/falco_rules.local.yaml >/dev/null <<'RULES'
- rule: Training namespace shell
  desc: Unexpected shells in the monitored namespace
  condition: >
    evt.type in (execve, execveat) and evt.dir = < and proc.name in (sh, bash)
    and k8s.ns.name = starfleet-036-010-02-03 and not proc.cmdline contains approved-
  output: Training shell (command=%proc.cmdline namespace=%k8s.ns.name pod=%k8s.pod.name uid=%k8s.pod.uid)
  priority: WARNING
RULES
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
for attempt in $(seq 1 30); do
  sudo systemctl is-active --quiet falco-modern-bpf.service && break
  sleep 2
done
sudo systemctl is-active --quiet falco-modern-bpf.service
