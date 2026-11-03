records=[json.loads(line) for line in command(['podman','exec','astro-ats-036-capstone-010-control-plane','cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','incident-report')['data']
denied=next(r for r in records if r.get('auditID')==report['deniedAuditID'] and r.get('stage')=='ResponseComplete')
assert denied['user']['username']==report['deniedActor'] and denied['objectRef']['resource']=='secrets' and denied['responseStatus']['code']==403, 'deniedAuditID must be the denied Secret request'
executed=next(r for r in records if r.get('auditID')==report['execAuditID'] and r.get('stage')==report['execStage'])
assert executed['verb']=='create' and executed['objectRef']['subresource']=='exec' and executed['objectRef']['name']==report['podName'], 'execAuditID must be the exec request'
assert executed['user']['username']==report['execActor'], 'Bind the exec finding to the authenticated user'
assert 'requestObject' not in denied and 'requestObject' not in executed, 'Do not capture payloads'
pod=get('pod',report['podName'])
labels=pod['metadata'].get('labels',{})
assert labels.get('quarantine')=='true' and labels.get('app')!='probe', 'Quarantine the exec target by label'
assert pod['status'].get('phase')=='Running', 'Keep the quarantined Pod running as evidence'
healthy=[item for item in json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items'] if item['status'].get('phase')=='Running']
assert len(healthy)==2 and all(item['metadata']['name']!=report['podName'] for item in healthy), 'The Deployment must serve with two other replicas'
