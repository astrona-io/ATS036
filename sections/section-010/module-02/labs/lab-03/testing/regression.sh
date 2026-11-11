#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py namespace-detection
sudo python3 /opt/astrona-live/check.py scoped-exceptions
sudo cp /etc/training/values.yaml /tmp/values.solved.yaml
sudo sed -i 's/and k8smeta.ns.name = monitored/and k8smeta.ns.name != unfinished/' /etc/training/values.yaml
sudo helm --kubeconfig /etc/training/kubeconfig upgrade falco /etc/training/falco-9.2.2.tgz -n falco --reuse-values -f /etc/training/values.yaml --wait --timeout=8m
export KUBECONFIG=/etc/training/kubeconfig
kubectl -n falco rollout restart daemonset/falco
kubectl -n falco rollout status daemonset/falco --timeout=300s
sleep 15
set +e
output=$(sudo python3 /opt/astrona-live/check.py scoped-exceptions); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Exclude the outside namespace' ]]
sudo cp /tmp/values.solved.yaml /etc/training/values.yaml
sudo helm --kubeconfig /etc/training/kubeconfig upgrade falco /etc/training/falco-9.2.2.tgz -n falco --reuse-values -f /etc/training/values.yaml --wait --timeout=8m
kubectl -n falco rollout restart daemonset/falco
kubectl -n falco rollout status daemonset/falco --timeout=300s
sleep 15
