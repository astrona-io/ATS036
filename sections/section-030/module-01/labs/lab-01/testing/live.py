def audit_records():
    return [json.loads(line) for line in node_exec(NODE, 'cat', '/var/log/training-audit/audit.jsonl').stdout.splitlines() if line.strip()]

def audit_record(report):
    record = next((record for record in audit_records() if record.get('auditID') == report['auditID'] and record.get('stage') == 'ResponseComplete'), None)
    assert record is not None, 'No audit event matches the submitted identity and stage'
    return record


if wants('denied-request'):
    report = get('configmap', 'audit-finding')['data']
    record = audit_record(report)
    assert record['user']['username'] == report['actor'] == 'system:serviceaccount:starfleet-036-030-01-01:threat-reader'
    assert record['objectRef']['resource'] == report['resource'] == 'secrets' and record['objectRef']['namespace'] == report['namespace'] == 'starfleet-036-030-01-01'
    assert str(record['responseStatus']['code']) == report['code'] == '403'
    assert record['stage'] == report['stage'] and record['requestURI'] == report['requestURI'], 'Preserve record identity and stage'
    assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture Secret payloads'

if wants('actor-attribution'):
    report = get('configmap', 'audit-finding')['data']
    record = audit_record(report)
    assert record['user']['username'] == report['actor'], 'Bind the finding to the authenticated user'
    pod = get('pod', 'threat-client')
    assert pod['spec']['serviceAccountName'] == 'threat-reader', 'Preserve the workload identity'
    assert report['podName'] == pod['metadata']['name'], 'Report the live Pod name'
    assert report['podUID'] == pod['metadata']['uid'], 'Report the live Pod UID'
    assert report['podIP'] == pod['status']['podIP'], 'Report the live Pod address'
    extra = record['user'].get('extra', {})
    assert report['podUID'] in extra.get('authentication.kubernetes.io/pod-uid', []), 'Bind the audit identity to the Pod UID'
    assert report['podName'] in extra.get('authentication.kubernetes.io/pod-name', []), 'Bind the audit identity to the Pod name'
    assert report['sourceIP'] in record.get('sourceIPs', []), 'Bind the source address to the audit event'
