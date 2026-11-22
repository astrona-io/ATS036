#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

sudo tee /etc/falco/falco_rules.local.yaml >/dev/null <<'RULES'
- rule: Unexpected probe shell
  desc: Shell execution by the probe account outside approved maintenance
  condition: >
    evt.type in (execve, execveat) and evt.dir = <
    and user.name = probe-user and proc.name in (sh, dash, bash)
  output: Shell started (command=%proc.cmdline user=%user.name process=%proc.name)
  priority: WARNING
  exceptions:
  - name: approved_maintenance
    fields: [proc.name, proc.cmdline]
    comps: [=, startswith]
    values:
    - [sh, "sh /opt/approved-maintenance.sh "]
RULES
sudo falco -V /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco-modern-bpf.service
for attempt in $(seq 1 30); do
  sudo systemctl is-active --quiet falco-modern-bpf.service && break
  sleep 2
done
sudo systemctl is-active --quiet falco-modern-bpf.service
