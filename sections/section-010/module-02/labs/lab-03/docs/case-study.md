---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster and Falco 0.45.2 as `falco-modern-bpf.service`. The namespaces `starfleet-036-010-02-03` and `outpost-036-010-02-03` each run a Pod named `reporter`. The rule `Training namespace shell` in `/etc/falco/falco_rules.local.yaml` selects the namespace `unfinished` and shows only the command line. Falco writes JSON alerts to `/var/log/falco-events.jsonl`.
