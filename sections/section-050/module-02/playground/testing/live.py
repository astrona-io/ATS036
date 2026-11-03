records=[json.loads(line) for line in command(['podman','exec','astro-ats-036-playground-050-02-control-plane','cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','audit-exec')['data']
matching=[record for record in records if record.get('objectRef',{}).get('resource')=='pods' and record['objectRef'].get('subresource')=='exec' and record['objectRef'].get('name')=='shuttle' and record['objectRef'].get('namespace')=='starfleet' and 'command=id' in record.get('requestURI','')]
assert matching, 'Run the command through the API server and audit it'
assert all(record.get('level')=='Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in matching), 'Keep bodies out of exec records'
assert report['command']=='id' and report['subresource']=='exec', 'Report the audited request'
assert kubectl('get','--raw=/readyz')=='ok', 'Preserve API availability'
