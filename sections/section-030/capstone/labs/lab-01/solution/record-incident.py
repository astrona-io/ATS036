import json,subprocess,tempfile,time
from pathlib import Path
CONTEXT="kind-astro-ats-036-capstone-030"
NODE="astro-ats-036-capstone-030-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='ats-036-capstone-030', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

def find_audit():
    records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
    matching=[record for record in records if record.get('stage')=='ResponseComplete' and record.get('user',{}).get('username')=='system:serviceaccount:starfleet:threat-reader' and record.get('objectRef',{}).get('resource')=='secrets' and record.get('objectRef',{}).get('namespace')=='starfleet' and record.get('responseStatus',{}).get('code')==403]
    assert matching, 'Wait for a real denied API record'
    return matching[-1]

def find_source():
    ip=run('kubectl','-n','outpost','get','pod','intruder','-o','jsonpath={.status.podIP}')
    assert ip, 'The intruder Pod has no address yet'
    for attempt in range(30):
        logs=run('kubectl','-n','starfleet','logs','-l','app=probe','--tail=-1')
        if any(line.split(' ')[0]==ip for line in logs.splitlines()):
            return ip
        time.sleep(3)
    raise AssertionError('The probe logs do not yet show requests from the intruder address')

def apply_configmap(name,data):
    with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
        source=Path(temporary)/'configmap-report.json'
        source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':name,'namespace':'starfleet'},'data':data}))
        run('kubectl','apply','-f',str(source))

record=find_audit()
ip=find_source()
apply_configmap('incident-report',{'actor':record['user']['username'],'auditID':record['auditID'],'deployment':'cache-sync','binding':'build-helper-edit','sourcePod':'intruder','sourceNamespace':'outpost','sourceIP':ip,'phases':'credential-access,persistence,lateral-movement','finding':'multi-phase-incident'})
