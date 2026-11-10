if wants('audit-finding'):
    import os
    records=[json.loads(line) for line in command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-lab-010-01-01")+"-control-plane"),'cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
    report=get('configmap','audit-finding')['data']
    record=next((record for record in records if record.get('auditID')==report['auditID'] and record.get('stage')=='ResponseComplete'), None)
    assert record is not None, "No audit event matches the submitted identity and stage"
    assert record['user']['username']==report['actor']=='system:serviceaccount:starfleet-036-010-01-01:threat-reader'
    assert record['objectRef']['resource']==report['resource']=='secrets' and record['objectRef']['namespace']==report['namespace']=='starfleet-036-010-01-01'
    assert str(record['responseStatus']['code'])==report['code']=='403'
    assert record['stage']==report['stage'] and record['requestURI']==report['requestURI'], 'Preserve record identity and stage'
    assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture Secret payloads'
