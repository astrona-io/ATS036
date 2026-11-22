#!/usr/bin/env bash
set -euo pipefail
sudo tee /etc/training/values.yaml >/dev/null <<'VALUES'
driver:
  kind: modern_ebpf
collectors:
  kubernetes:
    enabled: true
falco:
  json_output: true
  buffered_outputs: false
customRules:
  training.yaml: "- rule: Training namespace shell\n  desc: Unexpected shells in the\
    \ monitored training namespace\n  condition: evt.type in (execve, execveat) and\
    \ evt.dir = < and proc.name in (sh, bash) and k8smeta.ns.name = monitored and\
    \ not proc.cmdline contains approved-\n  output: Training shell (command=%proc.cmdline\
    \ namespace=%k8smeta.ns.name pod=%k8smeta.pod.name uid=%k8smeta.pod.uid)\n  priority:\
    \ WARNING\n"
VALUES
sudo helm --kubeconfig /etc/training/kubeconfig upgrade falco /etc/training/falco-9.2.2.tgz -n falco --reuse-values -f /etc/training/values.yaml --wait --timeout=8m
export KUBECONFIG=/etc/training/kubeconfig
kubectl -n falco rollout restart daemonset/falco
kubectl -n falco rollout status daemonset/falco --timeout=300s
sleep 15
