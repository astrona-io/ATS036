records=[json.loads(line) for line in command(['podman','exec','astro-ats-036-lab-010-01-01-control-plane','cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','audit-finding')['data']
record=next(record for record in records if record.get('auditID')==report['auditID'] and record.get('stage')=='ResponseComplete')
assert record['user']['username']==report['actor']=='system:serviceaccount:starfleet:threat-reader'
assert record['objectRef']['resource']==report['resource']=='secrets' and record['objectRef']['namespace']==report['namespace']=='starfleet'
assert str(record['responseStatus']['code'])==report['code']=='403'
assert record['stage']==report['stage'] and record['requestURI']==report['requestURI'], 'Preserve record identity and stage'
assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture Secret payloads'
