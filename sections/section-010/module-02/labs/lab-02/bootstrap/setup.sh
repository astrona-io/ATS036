#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates python3
case "$(uname -m)" in
  x86_64) arch=x86_64; checksum=cc237bf34e0886e1735bb4eb576b0a20a880f3afe158412522118f49fd260eb1 ;;
  aarch64) arch=aarch64; checksum=c4a8f03388522d7c630a76b68690aa297833442202e2e4960c9efbae637b40c9 ;;
  *) echo 'ERROR: unsupported Falco architecture'; exit 2 ;;
esac
curl --fail --location --retry 3 --max-time 180 "https://download.falco.org/packages/deb/stable/falco-0.45.2-$arch.deb" -o /tmp/falco.deb
printf '%s  /tmp/falco.deb\n' "$checksum" | sha256sum -c -
sudo env DEBIAN_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=none apt-get install -y -qq /tmp/falco.deb
sudo useradd --create-home --shell /bin/bash probe-user
sudo useradd --create-home --shell /bin/bash other-user
sudo tee /opt/approved-maintenance.sh >/dev/null <<'SCRIPT'
#!/bin/sh
sleep 0.2
SCRIPT
sudo chmod 0755 /opt/approved-maintenance.sh
sudo tee /etc/falco/training-rules.yaml >/dev/null <<'RULES'
- rule: Unfinished training rule
  desc: Deliberately matches no training shell
  condition: evt.type in (execve, execveat) and evt.dir = < and proc.name = no_training_process
  output: Unfinished (command=%proc.cmdline user=%user.name)
  priority: WARNING
RULES
sudo touch /var/log/training-falco.jsonl
sudo chmod 0644 /var/log/training-falco.jsonl
sudo tee /etc/systemd/system/training-falco.service >/dev/null <<'UNIT'
[Unit]
Description=Falco for the isolated training VM
After=network-online.target
[Service]
ExecStart=/usr/bin/falco -r /etc/falco/training-rules.yaml -o engine.kind=modern_ebpf -o json_output=true -o file_output.enabled=true -o file_output.filename=/var/log/training-falco.jsonl -o stdout_output.enabled=false -o syslog_output.enabled=false -o buffered_outputs=false
Restart=on-failure
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now training-falco
sleep 5
sudo systemctl is-active --quiet training-falco
sudo install -d /opt/astrona-falco
sudo tee /opt/astrona-falco/check.py >/dev/null <<'CHECKER'
import json, pathlib, subprocess, sys, time, uuid

def run(*args):
    return subprocess.run(args, text=True, capture_output=True, timeout=20)

def check():
    health = run('systemctl', 'is-active', 'training-falco')
    assert health.returncode == 0, 'Keep training-falco active'
    syntax = run('falco', '-V', '/etc/falco/training-rules.yaml')
    assert syntax.returncode == 0, 'Falco must accept the rule syntax: ' + syntax.stderr[-500:]
    log = pathlib.Path('/var/log/training-falco.jsonl')
    if not log.exists():
        raise RuntimeError('Falco output file is missing')
    offset = log.stat().st_size
    nonce = uuid.uuid4().hex
    cases = [
        ('probe-user', '/bin/sh', '-c', 'sleep 0.2', 'unexpected-' + nonce),
        ('probe-user', '/bin/sh', '/opt/approved-maintenance.sh', 'approved-' + nonce),
        ('other-user', '/bin/sh', '-c', 'sleep 0.2', 'outside-' + nonce),
        ('probe-user', '/bin/bash', '-c', 'sleep 0.2', 'second-' + nonce),
    ]
    for args in cases:
        result = run('runuser', '-u', args[0], '--', *args[1:])
        if result.returncode:
            raise RuntimeError('Test event failed: ' + result.stderr)
    events = []
    # Observe the whole window, including the negative cases. The final positive
    # event proves the sensor remained alive across the exception test.
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        time.sleep(1)
        if run('systemctl', 'is-active', 'training-falco').returncode:
            raise RuntimeError('Falco stopped during the event test')
    with log.open() as stream:
        stream.seek(offset)
        for line in stream:
            try:
                event = json.loads(line)
            except json.JSONDecodeError as error:
                raise RuntimeError('Invalid sensor JSON: ' + str(error))
            fields = event.get('output_fields', {})
            command = fields.get('proc.cmdline', '')
            if nonce in command:
                events.append(event)
    for marker in ('unexpected-', 'second-'):
        matches = [e for e in events if marker + nonce in e.get('output_fields', {}).get('proc.cmdline', '')]
        assert matches, 'Detect fresh sh and bash execution by probe-user'
        assert all(e.get('rule') == 'Unexpected probe shell' and e.get('priority') == 'Warning' and e['output_fields'].get('user.name') == 'probe-user' for e in matches), 'Alerts must identify the rule, priority, command and account'
    assert not any('approved-' + nonce in e.get('output_fields', {}).get('proc.cmdline', '') for e in events), 'Exclude only the approved maintenance script'
    assert not any('outside-' + nonce in e.get('output_fields', {}).get('proc.cmdline', '') for e in events), 'Scope the rule to probe-user'

if __name__ == '__main__':
    try:
        check()
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS: live Falco alerts cover unexpected shells and exclude approved and out-of-scope activity')
CHECKER
