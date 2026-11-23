#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Starts the audit collector outside the cluster and turns on the webhook audit
# backend of kube-apiserver with a wrong token and a policy that records nothing.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-036-lab-050-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-036-050-03-02"
source "$lab_directory/bootstrap/helpers.sh"

kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"

# The collector: a systemd service on the VM, outside the kube-apiserver Pod.
run_on_node install -d -m 0700 /etc/audit-collector
run_on_node install -d -m 0755 /var/log/audit-collector
run_on_node touch /var/log/audit-collector/events.jsonl
run_on_node openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
  -keyout /etc/audit-collector/collector.key -out /etc/audit-collector/collector.crt \
  -subj /CN=audit-collector -addext subjectAltName=IP:127.0.0.1 2>/dev/null
run_on_node install -m 0644 "$lab_directory/bootstrap/collector.py" /etc/audit-collector/collector.py
run_on_node tee /etc/systemd/system/audit-collector.service >/dev/null <<'UNIT'
[Unit]
Description=Audit collector of the lab (HTTPS receiver on 127.0.0.1:8443)
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /etc/audit-collector/collector.py
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
run_on_node systemctl daemon-reload
run_on_node systemctl enable --now audit-collector.service

# The webhook configuration (a kubeconfig file) and the audit policy.
ca_data="$(run_on_node base64 -w0 /etc/audit-collector/collector.crt)"
run_on_node install -d -m 0700 /etc/kubernetes/audit
run_on_node install -m 0600 /dev/null /etc/kubernetes/audit/webhook.yaml
run_on_node tee /etc/kubernetes/audit/webhook.yaml >/dev/null <<YAML
apiVersion: v1
kind: Config
clusters:
- name: audit-collector
  cluster:
    server: https://127.0.0.1:8443/audit
    certificate-authority-data: $ca_data
users:
- name: kube-apiserver
  user:
    token: incorrect-token
contexts:
- name: audit
  context:
    cluster: audit-collector
    user: kube-apiserver
current-context: audit
YAML
run_on_node install -m 0600 /dev/null /etc/kubernetes/audit/policy.yaml
run_on_node tee /etc/kubernetes/audit/policy.yaml >/dev/null <<'YAML'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: None
YAML

# Turn on the webhook backend: three flags and a read-only mount of /etc/kubernetes/audit.
edit_manifest kube-apiserver 's|^    - kube-apiserver$|&\n    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n    - --audit-webhook-config-file=/etc/kubernetes/audit/webhook.yaml\n    - --audit-webhook-batch-max-wait=1s|; s|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/audit\n      name: audit\n      readOnly: true|; s|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit|'
wait_for_argument "$node_name" kube-apiserver --audit-webhook-config-file=/etc/kubernetes/audit/webhook.yaml present
wait_for_api
