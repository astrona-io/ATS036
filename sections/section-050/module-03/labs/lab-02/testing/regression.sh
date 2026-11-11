#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py remote-delivery
sudo python3 /opt/astrona-live/check.py metadata-boundary
sudo cp /etc/training/audit-policy.json /tmp/policy.solved
sudo sed -i 's/Metadata/RequestResponse/' /etc/training/audit-policy.json
sudo reload-training-audit
set +e
output=$(sudo python3 /opt/astrona-live/check.py metadata-boundary); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Keep Secret request and response bodies out of the receiver' ]]
sudo cp /tmp/policy.solved /etc/training/audit-policy.json
sudo reload-training-audit
