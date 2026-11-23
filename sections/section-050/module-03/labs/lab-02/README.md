---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Deliver Audit Metadata Outside The Control Plane

Fix the audit webhook backend of the kube-apiserver so that Metadata events for Secrets and ConfigMaps of one namespace reach a TLS collector outside the kube-apiserver Pod, with no bodies and nothing from another namespace.

The task and solution use a VM from the `24.04-cks` image line with a one-node kubeadm cluster. `bootstrap/setup.sh` installs `bootstrap/collector.py` as `audit-collector.service` (a self-signed certificate for `IP:127.0.0.1`), writes `/etc/kubernetes/audit/webhook.yaml` with a wrong token and a `level: None` policy, and adds the audit flags and a read-only `hostPath` mount to the kube-apiserver manifest. The reference solution fixes both files and stops the kube-apiserver container with `crictl stop`, so the kubelet starts a new one that reads them. The graders read the webhook file with `kubectl config view --raw`, create Secrets and ConfigMaps with a random marker in both namespaces and read only the collector lines written after them. `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
