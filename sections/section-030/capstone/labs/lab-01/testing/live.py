import os
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=cache-sync','-o','json'))['items']
assert not pods, 'The cache-sync Pods must be gone'
assert not kubectl('-n','starfleet','get','rolebinding','build-helper-edit','--ignore-not-found','-o','name'), 'The attacker binding must be removed'
pod_ip=kubectl('-n','outpost','get','pod','intruder','-o','jsonpath={.status.podIP}')
report=get('configmap','incident-report')['data']
assert report['sourceIP']==pod_ip, 'The recorded address must belong to the intruder Pod'
logs=kubectl('-n','starfleet','logs','-l','app=probe','--tail=-1')
assert any(line.split(' ')[0]==pod_ip for line in logs.splitlines()), 'The probe logs must show requests from the recorded address'
report=get('configmap','incident-report')['data']
records=[json.loads(line) for line in command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-capstone-030")+"-control-plane"),'cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
record=next(record for record in records if record.get('auditID')==report['auditID'] and record.get('stage')=='ResponseComplete')
assert record['user']['username']==report['actor']=='system:serviceaccount:starfleet:threat-reader'
assert record['objectRef']['resource']=='secrets' and record['responseStatus']['code']==403
assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture Secret payloads'
assert kubectl('-n','outpost','get','pod','intruder','-o','jsonpath={.metadata.labels.incident}')=='quarantine', 'Quarantine the intruder Pod without deleting it'
