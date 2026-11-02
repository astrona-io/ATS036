import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-playground-030-01"
NODE="astro-ats-036-playground-030-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-playground-030-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
matching=[record for record in records if record.get('stage')=='ResponseComplete' and record.get('user',{}).get('username')=='system:serviceaccount:starfleet:threat-reader' and record.get('objectRef',{}).get('resource')=='secrets' and record.get('objectRef',{}).get('namespace')=='starfleet' and record.get('responseStatus',{}).get('code')==403]
assert matching, 'Wait for a real denied API record'
record=matching[-1]
report_name='audit-finding';report={'actor':record['user']['username'],'resource':record['objectRef']['resource'],'namespace':record['objectRef']['namespace'],'code':str(record['responseStatus']['code']),'finding':'unauthorized-secret-read','auditID':record['auditID'],'stage':record['stage'],'requestURI':record['requestURI']}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet'},'data':report}))
    run('kubectl','apply','-f',str(source))

