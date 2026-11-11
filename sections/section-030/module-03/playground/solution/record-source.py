import os
import json,subprocess,tempfile,time
from pathlib import Path
CONTEXT=os.environ.get("ASTRONA_KUBE_CONTEXT") or "kind-astro-ats-036-playground-030-03"
CLUSTER=os.environ.get("ASTRONA_KIND_CLUSTER") or "astro-ats-036-playground-030-03"
NODE=CLUSTER+"-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'

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

ip=find_source()
apply_configmap('lateral-finding',{'sourcePod':'intruder','sourceNamespace':'outpost','sourceIP':ip,'target':'probe','finding':'lateral-movement-to-probe'})
