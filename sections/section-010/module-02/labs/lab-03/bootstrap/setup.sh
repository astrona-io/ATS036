#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# The image ships Falco with the modern eBPF driver; this script adds the two
# reporter Pods, the unfinished rule and the JSON file output, then starts
# falco-modern-bpf.service.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-010-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
for namespace in starfleet-036-010-02-03 outpost-036-010-02-03; do
  kubectl -n "$namespace" wait --for=condition=Ready pod/reporter --timeout=180s
done

# The unfinished rule selects a namespace that does not exist.
sudo tee /etc/falco/falco_rules.local.yaml >/dev/null <<'RULES'
- rule: Training namespace shell
  desc: Unexpected shells in the monitored namespace
  condition: >
    evt.type in (execve, execveat) and evt.dir = < and proc.name in (sh, bash)
    and k8s.ns.name = unfinished and not proc.cmdline contains approved-
  output: Training shell (command=%proc.cmdline)
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
