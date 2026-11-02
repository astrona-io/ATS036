records=[json.loads(line) for line in command(['podman','exec','astro-ats-036-playground-050-01-control-plane','cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
matching=[record for record in records if record.get('stage')=='ResponseComplete' and record.get('verb')=='get' and record.get('objectRef',{}).get('resource')=='secrets' and record.get('objectRef',{}).get('namespace')=='starfleet' and record.get('objectRef',{}).get('name')=='audit-token']
assert matching and all(record.get('level')=='Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in matching), 'Collect metadata without Secret payloads'
assert kubectl('get','--raw=/readyz')=='ok', 'Preserve API availability'
