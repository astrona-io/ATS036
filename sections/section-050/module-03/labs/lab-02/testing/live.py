# Checks that create real objects through kube-apiserver and read the audit
# events that reach the collector. check.py runs this file with NODE,
# node_exec(), command(), kubectl(), get() and wants() already defined.
import json
import time
import uuid

WEBHOOK = '/etc/kubernetes/audit/webhook.yaml'
EVENTS = '/var/log/audit-collector/events.jsonl'
SCOPED = 'starfleet-036-050-03-02'
OUTSIDE = 'outpost-036-050-03-02'


def webhook_settings():
    raw = node_exec(NODE, 'kubectl', 'config', 'view', '--kubeconfig', WEBHOOK, '--raw', '-o', 'json', success=False)
    assert raw.returncode == 0, WEBHOOK + ' must stay a valid kubeconfig file'
    config = json.loads(raw.stdout)
    users = config.get('users') or [{}]
    clusters = config.get('clusters') or [{}]
    return users[0].get('user', {}), clusters[0].get('cluster', {})


def fresh_events():
    """Create a Secret and a ConfigMap in both namespaces; return the probes and the new collector events."""
    collector = node_exec(NODE, 'systemctl', 'is-active', '--quiet', 'audit-collector.service', success=False)
    assert collector.returncode == 0, 'audit-collector.service must stay active'
    offset = int(node_exec(NODE, 'stat', '-c', '%s', EVENTS).stdout.strip())
    marker = uuid.uuid4().hex
    value = 'training-body-' + marker
    probes = [(namespace, kind, namespace + '-' + kind + '-' + marker) for namespace in (SCOPED, OUTSIDE) for kind in ('secret', 'configmap')]
    created = []
    try:
        for namespace, kind, name in probes:
            if kind == 'secret':
                kubectl('-n', namespace, 'create', 'secret', 'generic', name, '--from-literal=value=' + value)
            else:
                kubectl('-n', namespace, 'create', 'configmap', name, '--from-literal=value=' + value)
            created.append((namespace, kind, name))
        names = {name for namespace, kind, name in probes if namespace == SCOPED}
        events, text = [], ''
        for _ in range(12):
            time.sleep(1)
            text = node_exec(NODE, 'tail', '-c', '+' + str(offset + 1), EVENTS).stdout
            events = [json.loads(line) for line in text.splitlines() if line.strip()]
            done = {event.get('objectRef', {}).get('name') for event in events if event.get('stage') == 'ResponseComplete'}
            if names <= done:
                break
    finally:
        for namespace, kind, name in created:
            kubectl('-n', namespace, 'delete', kind, name, '--ignore-not-found')
    return probes, events, text, value


def scoped_creates(probes, events):
    found = []
    for namespace, kind, name in probes[:2]:
        matching = [event for event in events if event.get('objectRef', {}).get('name') == name
                    and event.get('verb') == 'create' and event.get('stage') == 'ResponseComplete']
        assert matching, 'The create event of ' + kind + ' ' + name + ' must reach the collector'
        for event in matching:
            assert event.get('auditID') and event.get('user', {}).get('username') \
                and event['objectRef'].get('namespace') == namespace and event['objectRef'].get('resource') == kind + 's' \
                and event.get('responseStatus', {}).get('code') == 201, \
                'Each event must keep its auditID, user, object and response status 201'
        found.extend(matching)
    return found


remote_delivery = wants('remote-delivery')
metadata_boundary = wants('metadata-boundary')
if remote_delivery or metadata_boundary:
    user, cluster = webhook_settings()
    if remote_delivery:
        assert user.get('token') == 'training-audit-token', 'Set the token of the webhook user to training-audit-token'
        assert cluster.get('server') == 'https://127.0.0.1:8443/audit', 'Keep the collector address https://127.0.0.1:8443/audit'
        assert cluster.get('certificate-authority-data') and not cluster.get('insecure-skip-tls-verify'), \
            'Keep certificate-authority-data and verify the collector certificate'
    probes, events, text, value = fresh_events()
    delivered = scoped_creates(probes, events)
    if metadata_boundary:
        assert all(event.get('level') == 'Metadata' and 'requestObject' not in event and 'responseObject' not in event for event in delivered), \
            'Record the scoped Secrets and ConfigMaps at level Metadata, without request or response bodies'
        names = {name for namespace, kind, name in probes}
        assert not any(event.get('stage') == 'RequestReceived' for event in events if event.get('objectRef', {}).get('name') in names), \
            'Omit the RequestReceived stage'
        assert not any(event.get('objectRef', {}).get('namespace') == OUTSIDE for event in events), \
            'Record nothing for ' + OUTSIDE
        assert value not in text, 'No Secret or ConfigMap value may reach the collector'
