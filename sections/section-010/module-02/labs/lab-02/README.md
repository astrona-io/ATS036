---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Test A Falco Rule Against Live Processes

Write a Falco rule with a narrow exception and prove it with real process starts on the node: new `sh` and `bash` shells of `probe-user` alert, the approved maintenance script and `other-user` do not.

The task and solution use a VM from the `24.04-cks` image line (currently the dated tag `24.04-cks-20261122`) with a one-node kubeadm cluster and Falco 0.45.2. The image ships Falco with the service stopped; `bootstrap/setup.sh` adds the accounts, the unfinished rule in `/etc/falco/falco_rules.local.yaml` and the JSON file output in `/etc/falco/config.d/training-output.yaml`, then starts `falco-modern-bpf.service`. The graders start four shells with `runuser` and a random marker, then read only the alerts written after them. `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
