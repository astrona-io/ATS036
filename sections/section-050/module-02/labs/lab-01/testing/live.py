def audit_records():
    return [json.loads(line) for line in node_exec(NODE, 'cat', '/var/log/training-audit/audit.jsonl').stdout.splitlines() if line.strip()]

if wants('exec-audited'):
    matching = [record for record in audit_records() if record.get('objectRef', {}).get('resource') == 'pods' and record['objectRef'].get('subresource') == 'exec' and record['objectRef'].get('name') == 'shuttle' and record['objectRef'].get('namespace') == 'starfleet-036-050-02-01' and 'command=id' in record.get('requestURI', '')]
    assert matching, 'Run the command through the API server and audit it'
    assert all(record.get('level') == 'Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in matching), 'Keep bodies out of exec records'
    assert kubectl('get', '--raw=/readyz') == 'ok', 'Preserve API availability'

if wants('audit-exec'):
    report = get('configmap', 'audit-exec')['data']
    assert report['command'] == 'id' and report['subresource'] == 'exec', 'Report the audited request'
