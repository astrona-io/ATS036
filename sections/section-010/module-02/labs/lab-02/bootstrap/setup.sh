#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# The image ships Falco with the modern eBPF driver; this script only adds the
# lab accounts, the unfinished rule and the JSON file output, then starts
# falco-modern-bpf.service.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

for account in probe-user other-user; do
  id "$account" >/dev/null 2>&1 || sudo useradd --create-home --shell /bin/bash "$account"
done
sudo tee /opt/approved-maintenance.sh >/dev/null <<'SCRIPT'
#!/bin/sh
sleep 0.2
SCRIPT
sudo chmod 0755 /opt/approved-maintenance.sh

# The unfinished rule matches no process of the exercise.
sudo tee /etc/falco/falco_rules.local.yaml >/dev/null <<'RULES'
- rule: Unfinished training rule
  desc: Deliberately matches no training shell
  condition: evt.type in (execve, execveat) and evt.dir = < and proc.name = no_training_process
  output: Unfinished (command=%proc.cmdline user=%user.name)
  priority: WARNING
RULES

# Falco reads every file in /etc/falco/config.d after falco.yaml.
sudo mkdir -p /etc/falco/config.d
sudo tee /etc/falco/config.d/training-output.yaml >/dev/null <<'CONFIG'
json_output: true
json_include_output_property: true
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco-events.jsonl
CONFIG
sudo touch /var/log/falco-events.jsonl
sudo falco -V /etc/falco/falco_rules.local.yaml >/dev/null
sudo systemctl start falco-modern-bpf.service
for attempt in $(seq 1 30); do
  sudo systemctl is-active --quiet falco-modern-bpf.service && break
  sleep 2
done
sudo systemctl is-active --quiet falco-modern-bpf.service
