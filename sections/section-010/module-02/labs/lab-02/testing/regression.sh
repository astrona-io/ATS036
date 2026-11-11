#!/usr/bin/env bash
set -euo pipefail
rules=/etc/falco/training-rules.yaml
backup=$(mktemp)
sudo cat "$rules" > "$backup"
reload() { sudo falco -V "$rules" >/dev/null; sudo systemctl restart training-falco; sleep 5; }
restore() { sudo cp "$backup" "$rules"; reload; rm -f "$backup"; }
trap restore EXIT
expect_failure() {
  set +e
  output=$(sudo python3 /opt/astrona-falco/check.py 2>&1)
  status=$?
  set -e
  printf '%s\n' "$output"
  [[ "$status" == 1 && "$output" == "FAIL: $1" ]] || exit 2
}
sed '/  exceptions:/,$d' "$backup" | sudo tee "$rules" >/dev/null
reload
expect_failure 'Exclude only the approved maintenance script'
sed 's/sh, dash, bash/sh, dash/' "$backup" | sudo tee "$rules" >/dev/null
reload
expect_failure 'Detect fresh sh and bash execution by probe-user'
sed 's/user.name = probe-user/user.name in (probe-user, other-user)/' "$backup" | sudo tee "$rules" >/dev/null
reload
expect_failure 'Scope the rule to probe-user'
printf 'PASS: missing exceptions, missed shells and excessive scope are rejected\n'
