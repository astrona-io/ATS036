import os
import json,subprocess,tempfile,time
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
CONTEXT=os.environ.get("ASTRONA_KUBE_CONTEXT") or "kind-astro-ats-036-lab-010-03-02"
CLUSTER=os.environ.get("ASTRONA_KIND_CLUSTER") or "astro-ats-036-lab-010-03-02"
ENGINE=os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"
NODE=CLUSTER+"-control-plane"
NAMESPACE="starfleet-036-010-03-02"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run(ENGINE,'inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')==CLUSTER, 'Refusing an unrelated node container'
def node(*args):return run(ENGINE,'exec',NODE,*args)

def exec_records():
    records=[]
    for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines():
        try:
            record=json.loads(line)
        except ValueError:
            continue
        reference=record.get('objectRef',{})
        if reference.get('resource')=='pods' and reference.get('subresource')=='exec' and reference.get('namespace')==NAMESPACE and reference.get('name','').startswith('probe-'):
            records.append(record)
    return records

matching=[]
for attempt in range(30):
    matching=exec_records()
    if matching:
        break
    time.sleep(1)
assert matching, 'Wait for a real exec audit record'
record=matching[0]
pod_name=record['objectRef']['name']
container=parse_qs(urlsplit(record['requestURI']).query)['container'][0]
pod=json.loads(run('kubectl','-n',NAMESPACE,'get','pod',pod_name,'-o','json'))
container_id=next(status['containerID'] for status in pod['status']['containerStatuses'] if status['name']==container)
report={'auditID':record['auditID'],'podName':pod_name,'container':container,'nodeName':pod['spec']['nodeName'],'containerID':container_id}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-exec-correlation.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'exec-correlation','namespace':NAMESPACE},'data':report}))
    run('kubectl','apply','-f',str(source))
