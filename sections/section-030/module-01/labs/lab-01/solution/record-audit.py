import os
import json,subprocess,tempfile
from pathlib import Path
CONTEXT=os.environ.get("ASTRONA_KUBE_CONTEXT") or "kind-astro-ats-036-lab-030-01-01"
CLUSTER=os.environ.get("ASTRONA_KIND_CLUSTER") or "astro-ats-036-lab-030-01-01"
NODE=CLUSTER+"-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run((os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')==CLUSTER, 'Refusing an unrelated node container'
def node(*args):return run((os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',NODE,*args)

import time
matching=[]
for attempt in range(30):
    records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
    matching=[record for record in records if record.get('stage')=='ResponseComplete' and record.get('user',{}).get('username')=='system:serviceaccount:starfleet-036-030-01-01:threat-reader' and record.get('objectRef',{}).get('resource')=='secrets' and record.get('objectRef',{}).get('namespace')=='starfleet-036-030-01-01' and record.get('responseStatus',{}).get('code')==403]
    if matching:
        break
    time.sleep(1)
assert matching, 'Wait for a real denied API record'
record=matching[-1]
report_name='audit-finding';report={'actor':record['user']['username'],'resource':record['objectRef']['resource'],'namespace':record['objectRef']['namespace'],'code':str(record['responseStatus']['code']),'finding':'unauthorized-secret-read','auditID':record['auditID'],'stage':record['stage'],'requestURI':record['requestURI']}

pod=json.loads(run('kubectl','-n','starfleet-036-030-01-01','get','pod','threat-client','-o','json'))
report.update(podName=pod['metadata']['name'], podUID=pod['metadata']['uid'], sourceIP=pod['status']['podIP'])

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet-036-030-01-01'},'data':report}))
    run('kubectl','apply','-f',str(source))

