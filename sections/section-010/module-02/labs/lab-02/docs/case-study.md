---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster and Falco 0.45.2 as `falco-modern-bpf.service`. The custom rule file `/etc/falco/falco_rules.local.yaml` holds a rule that matches no process. Falco writes JSON alerts to `/var/log/falco-events.jsonl`. The accounts `probe-user` and `other-user` exist, and `/opt/approved-maintenance.sh` is the approved maintenance script.
