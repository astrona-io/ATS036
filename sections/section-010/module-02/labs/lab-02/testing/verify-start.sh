#!/usr/bin/env bash
set -euo pipefail
sudo systemctl is-active --quiet training-falco
set +e
output=$(sudo python3 /opt/astrona-falco/check.py 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[[ "$status" == 1 && "$output" == 'FAIL: Detect fresh sh and bash execution by probe-user' ]] || exit 2
printf 'PASS: the unfinished rule misses the generated shell events\n'
