import os
records=[json.loads(line) for line in command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-playground-010-03")+"-control-plane"),'cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','exec-finding')['data']
record=next(record for record in records if record.get('auditID')==report['auditID'] and record.get('stage')==report['stage'])
assert record['stage'] in ('ResponseStarted','ResponseComplete'), 'Use a stage that the API server logged for the exec request'
assert record['user']['username']==report['actor'], 'Bind the finding to the authenticated user'
assert record['verb']==report['verb']=='create'
assert record['objectRef']['resource']==report['resource']=='pods' and record['objectRef']['subresource']==report['subresource']=='exec'
assert record['objectRef']['namespace']==report['namespace']=='starfleet'
assert record['objectRef']['name']==report['podName'] and report['podName'].startswith('probe-'), 'Name the Pod that received the exec request'
assert record['requestURI']==report['requestURI'] and 'command=' in record['requestURI'], 'Preserve the request URI'
assert 'requestObject' not in record and 'responseObject' not in record, 'Do not capture request payloads'
