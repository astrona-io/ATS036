records=[json.loads(line) for line in command(['podman','exec','astro-ats-036-capstone-050-control-plane','cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','audit-investigation')['data']
by_id={record['auditID']:record for record in records if record.get('stage')=='ResponseComplete'}
secret,denied,execute=(by_id[report[key]] for key in ('secretAuditID','deniedAuditID','execAuditID'))
assert len({report['secretAuditID'],report['deniedAuditID'],report['execAuditID']})==3, 'Use three different records'
assert secret['objectRef']['name']=='audit-token' and secret['verb']=='get' and secret['responseStatus']['code']==200 and 'impersonatedUser' not in secret, 'Record the successful read'
assert denied['objectRef']['name']=='audit-token' and denied['responseStatus']['code']==403 and denied['impersonatedUser']['username']==report['deniedUser']=='system:serviceaccount:outpost:default', 'Record the denied read'
assert execute['objectRef'].get('subresource')=='exec' and execute['objectRef']['name']==report['execPod']=='shuttle' and 'command=id' in execute['requestURI'], 'Record the exec request'
assert all('requestObject' not in record and 'responseObject' not in record for record in (secret,denied,execute)), 'Keep bodies out of the records'
assert not any('audit-disposable' in json.dumps(record) for record in records), 'Keep the Secret value out of the log'
assert kubectl('get','--raw=/readyz')=='ok', 'Preserve API availability'
