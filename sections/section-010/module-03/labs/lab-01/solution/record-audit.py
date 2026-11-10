import os
import json,subprocess,tempfile
from pathlib import Path
CONTEXT=os.environ.get("ASTRONA_KUBE_CONTEXT") or "kind-astro-ats-036-lab-010-03-01"
CLUSTER=os.environ.get("ASTRONA_KIND_CLUSTER") or "astro-ats-036-lab-010-03-01"
NODE=CLUSTER+"-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run((os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')==CLUSTER, 'Refusing an unrelated node container'
def node(*args):return run((os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
matching=[record for record in records if record.get('verb')=='create' and record.get('objectRef',{}).get('resource')=='pods' and record.get('objectRef',{}).get('subresource')=='exec' and record.get('objectRef',{}).get('namespace')=='starfleet-036-010-03-01' and record.get('objectRef',{}).get('name','').startswith('probe-') and record.get('stage') in ('ResponseStarted','ResponseComplete')]
assert matching, 'Wait for a real exec audit record'
record=matching[0]
report_name='exec-finding';report={'actor':record['user']['username'],'verb':record['verb'],'resource':record['objectRef']['resource'],'subresource':record['objectRef']['subresource'],'namespace':record['objectRef']['namespace'],'podName':record['objectRef']['name'],'finding':'unexpected-exec','auditID':record['auditID'],'stage':record['stage'],'requestURI':record['requestURI']}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet-036-010-03-01'},'data':report}))
    run('kubectl','apply','-f',str(source))
