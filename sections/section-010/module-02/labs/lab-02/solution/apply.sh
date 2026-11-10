#!/usr/bin/env bash
set -euo pipefail
sudo tee /etc/falco/training-rules.yaml >/dev/null <<'RULES'
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
sudo falco -V /etc/falco/training-rules.yaml
sudo systemctl restart training-falco
sleep 5
sudo systemctl is-active --quiet training-falco
