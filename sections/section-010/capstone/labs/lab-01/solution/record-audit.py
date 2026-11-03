import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-capstone-010"
NODE="astro-ats-036-capstone-010-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-capstone-010', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
denied=[r for r in records if r.get('stage')=='ResponseComplete' and r.get('user',{}).get('username')=='system:serviceaccount:starfleet:threat-reader' and r.get('objectRef',{}).get('resource')=='secrets' and r.get('responseStatus',{}).get('code')==403]
execs=[r for r in records if r.get('verb')=='create' and r.get('objectRef',{}).get('subresource')=='exec' and r.get('objectRef',{}).get('namespace')=='starfleet' and r.get('objectRef',{}).get('name','').startswith('probe-') and r.get('stage') in ('ResponseStarted','ResponseComplete')]
assert denied and execs, 'Wait for the real audit records'
denied_record=denied[-1]; exec_record=execs[0]
pod_name=exec_record['objectRef']['name']
report={'deniedActor':denied_record['user']['username'],'deniedAuditID':denied_record['auditID'],'execActor':exec_record['user']['username'],'execAuditID':exec_record['auditID'],'execStage':exec_record['stage'],'podName':pod_name,'response':'quarantined'}
with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'incident-report','namespace':'starfleet'},'data':report}))
    run('kubectl','apply','-f',str(source))
run('kubectl','-n','starfleet','label','pod',pod_name,'app-','release-','quarantine=true','--overwrite')
