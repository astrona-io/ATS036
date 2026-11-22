---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Scope Live Falco Events With Kubernetes Metadata

Fix a Falco rule so that a shell in one namespace alerts with the namespace, Pod name and Pod UID, while an approved command and the same Pod in another namespace stay quiet.

The task and solution use a VM from the `24.04-cks` image line (currently the dated tag `24.04-cks-20261122`) with a one-node kubeadm cluster and Falco 0.45.2. The image ships Falco with the service stopped; `bootstrap/setup.sh` creates the two `reporter` Pods, the unfinished rule and the JSON file output, then starts `falco-modern-bpf.service`. The Kubernetes fields come from the container plugin that Falco 0.45 loads by default; no Helm chart or k8smeta collector is used. The graders run `kubectl exec` shells with a random marker and read only the alerts written after them. `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
