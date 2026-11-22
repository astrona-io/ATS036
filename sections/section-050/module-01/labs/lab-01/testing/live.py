def audit_records():
    return [json.loads(line) for line in node_exec(NODE, 'cat', '/var/log/training-audit/audit.jsonl').stdout.splitlines() if line.strip()]

if wants('secret-read-audited'):
    matching = [record for record in audit_records() if record.get('stage') == 'ResponseComplete' and record.get('verb') == 'get' and record.get('objectRef', {}).get('resource') == 'secrets' and record.get('objectRef', {}).get('namespace') == 'starfleet-036-050-01-01' and record.get('objectRef', {}).get('name') == 'audit-token']
    assert matching and all(record.get('level') == 'Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in matching), 'Collect metadata without Secret payloads'
    assert kubectl('get', '--raw=/readyz') == 'ok', 'Preserve API availability'
