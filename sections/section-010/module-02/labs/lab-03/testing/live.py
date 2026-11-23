# Checks that start real shells in the two reporter Pods and read the Falco
# alerts that follow them. check.py runs this file with NODE, node_exec(),
# command(), kubectl(), get() and wants() already defined.
import json
import time
import uuid

SERVICE = 'falco-modern-bpf.service'
RULES = '/etc/falco/falco_rules.local.yaml'
EVENTS = '/var/log/falco-events.jsonl'
RULE = 'Training namespace shell'
MONITORED = 'starfleet-036-010-02-03'
OUTSIDE = 'outpost-036-010-02-03'


def falco_active():
    return node_exec(NODE, 'systemctl', 'is-active', '--quiet', SERVICE, success=False).returncode == 0


def fresh_alerts():
    """Run the four test shells with a new marker; return the marker and the new alerts of RULE."""
    assert falco_active(), SERVICE + ' must stay active'
    syntax = node_exec(NODE, 'falco', '-V', RULES, success=False)
    assert syntax.returncode == 0, 'Falco must accept ' + RULES
    size = node_exec(NODE, 'stat', '-c', '%s', EVENTS, success=False)
    assert size.returncode == 0, EVENTS + ' is missing; keep the Falco file output'
    offset = int(size.stdout.strip())
    marker = uuid.uuid4().hex
    cases = ((MONITORED, 'unexpected-'), (MONITORED, 'approved-'), (OUTSIDE, 'outside-'), (MONITORED, 'later-'))
    for namespace, case in cases:
        kubectl('-n', namespace, 'exec', 'reporter', '--', 'sh', '-c', 'sleep 0.2', case + marker)
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
        if alert.get('rule') == RULE and marker in alert.get('output', ''):
            alerts.append(alert)
    return marker, alerts


def with_marker(alerts, text):
    return [alert for alert in alerts if text in alert.get('output', '')]


namespace_detection = wants('namespace-detection')
scoped_exceptions = wants('scoped-exceptions')
if namespace_detection or scoped_exceptions:
    uid = get('pod', 'reporter', MONITORED)['metadata']['uid']
    marker, alerts = fresh_alerts()
    for case in ('unexpected-', 'later-'):
        found = with_marker(alerts, case + marker)
        assert found, 'Falco must alert on both new shells in the reporter Pod of ' + MONITORED + ' with rule ' + RULE
        if namespace_detection:
            for alert in found:
                fields = alert.get('output_fields', {})
                assert (fields.get('k8s.ns.name'), fields.get('k8s.pod.name'), fields.get('k8s.pod.uid')) == (MONITORED, 'reporter', uid), \
                    'Each alert must show the namespace, the Pod name and the Pod UID of the reporter Pod'
    if scoped_exceptions:
        assert not with_marker(alerts, 'approved-' + marker), 'Exclude the approved command without silencing other shells'
        assert not with_marker(alerts, 'outside-' + marker), 'Scope the rule to ' + MONITORED + '; ' + OUTSIDE + ' must not alert'
