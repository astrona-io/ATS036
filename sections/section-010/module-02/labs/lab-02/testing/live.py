# Checks that start real processes on the lab VM and read the Falco alerts
# that follow them. check.py runs this file with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined.
import json
import time
import uuid

SERVICE = 'falco-modern-bpf.service'
RULES = '/etc/falco/falco_rules.local.yaml'
EVENTS = '/var/log/falco-events.jsonl'
RULE = 'Unexpected probe shell'


def falco_active():
    return node_exec(NODE, 'systemctl', 'is-active', '--quiet', SERVICE, success=False).returncode == 0


def fresh_alerts():
    """Start the four test shells with a new marker; return the marker and the new alerts of RULE."""
    assert falco_active(), SERVICE + ' must stay active'
    syntax = node_exec(NODE, 'falco', '-V', RULES, success=False)
    assert syntax.returncode == 0, 'Falco must accept ' + RULES
    size = node_exec(NODE, 'stat', '-c', '%s', EVENTS, success=False)
    assert size.returncode == 0, EVENTS + ' is missing; keep the Falco file output'
    offset = int(size.stdout.strip())
    marker = uuid.uuid4().hex
    cases = (
        ('probe-user', '/bin/sh', '-c', 'sleep 0.2', 'unexpected-' + marker),
        ('probe-user', '/bin/sh', '/opt/approved-maintenance.sh', 'approved-' + marker),
        ('other-user', '/bin/sh', '-c', 'sleep 0.2', 'outside-' + marker),
        ('probe-user', '/bin/bash', '-c', 'sleep 0.2', 'second-' + marker),
    )
    for account, *arguments in cases:
        node_exec(NODE, 'runuser', '-u', account, '--', *arguments)
    # Watch the whole window: the last positive case proves that Falco was
    # still running after the two negative cases.
    for _ in range(8):
        time.sleep(1)
        assert falco_active(), 'Falco stopped during the event test'
    lines = node_exec(NODE, 'tail', '-c', '+' + str(offset + 1), EVENTS).stdout.splitlines()
    alerts = []
    for line in lines:
        try:
            alert = json.loads(line)
        except ValueError:
            continue
        if alert.get('rule') == RULE and marker in alert.get('output_fields', {}).get('proc.cmdline', ''):
            alerts.append(alert)
    return marker, alerts


def with_marker(alerts, text):
    return [alert for alert in alerts if text in alert['output_fields'].get('proc.cmdline', '')]


shell_alerts = wants('shell-alerts')
scoped_exception = wants('scoped-exception')
if shell_alerts or scoped_exception:
    marker, alerts = fresh_alerts()
    for case in ('unexpected-', 'second-'):
        found = with_marker(alerts, case + marker)
        assert found, 'Falco must alert on new sh and bash shells of probe-user with rule ' + RULE
        if shell_alerts:
            assert all(alert.get('priority') == 'Warning' and alert['output_fields'].get('user.name') == 'probe-user' for alert in found), \
                'Each alert must show priority WARNING, the command line and the account probe-user'
    if scoped_exception:
        assert not with_marker(alerts, 'approved-' + marker), 'Exclude only the approved maintenance command'
        assert not with_marker(alerts, 'outside-' + marker), 'Scope the rule to probe-user; other-user must not alert'
