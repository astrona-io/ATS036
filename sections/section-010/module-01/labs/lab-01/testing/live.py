def audit_records():
    return [json.loads(line) for line in node_exec(NODE, 'cat', '/var/log/training-audit/audit.jsonl').stdout.splitlines() if line.strip()]

def audit_record(report):
    record = next((record for record in audit_records() if record.get('auditID') == report['auditID'] and record.get('stage') == 'ResponseComplete'), None)
    assert record is not None, 'No audit event matches the submitted identity and stage'
    return record


if wants('audit-event-identity'):
    report = get('configmap', 'audit-finding')['data']
    record = audit_record(report)
    assert record['user']['username'] == report['actor'] == 'system:serviceaccount:starfleet-036-010-01-01:threat-reader'
    assert record['stage'] == report['stage'] and record['requestURI'] == report['requestURI'], 'Preserve record identity and stage'

if wants('denied-secret-read'):
    report = get('configmap', 'audit-finding')['data']
    record = audit_record(report)
    assert record['objectRef']['resource'] == report['resource'] == 'secrets' and record['objectRef']['namespace'] == report['namespace'] == 'starfleet-036-010-01-01'
    assert str(record['responseStatus']['code']) == report['code'] == '403'
    assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture Secret payloads'
