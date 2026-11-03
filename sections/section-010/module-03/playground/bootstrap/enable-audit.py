import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-playground-010-03"
NODE="astro-ats-036-playground-010-03-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-playground-010-03', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)
def put(path,content):
    with tempfile.TemporaryDirectory(prefix='training-node-') as temporary:
        source=Path(temporary)/'content';source.write_text(content)
        run('podman','cp',str(source),NODE+':'+path)
def api_manifest():
    with tempfile.TemporaryDirectory(prefix='training-api-') as temporary:
        source=Path(temporary)/'pod.yaml';source.write_text(node('cat','/etc/kubernetes/manifests/kube-apiserver.yaml'))
        return json.loads(run('kubectl','create','--dry-run=client','--validate=false','-f',str(source),'-o','json'))
def configure_audit(policy):
    manifest=api_manifest(); container=manifest['spec']['containers'][0]
    flags={'audit-policy-file':'/etc/kubernetes/training-audit-policy.json','audit-log-path':'/var/log/training-audit/audit.jsonl','audit-log-maxage':'1','audit-log-maxbackup':'1','audit-log-maxsize':'10'}
    container['command']=[arg for arg in container['command'] if not any(arg.startswith('--'+flag+'=') for flag in flags)]+['--'+flag+'='+value for flag,value in flags.items()]
    manifest['spec']['volumes']=[volume for volume in manifest['spec'].get('volumes',[]) if volume['name'] not in ('training-audit-policy','training-audit-log')]+[{'name':'training-audit-policy','hostPath':{'path':'/etc/kubernetes/training-audit-policy.json','type':'File'}},{'name':'training-audit-log','hostPath':{'path':'/var/log/training-audit','type':'DirectoryOrCreate'}}]
    container['volumeMounts']=[mount for mount in container.get('volumeMounts',[]) if mount['name'] not in ('training-audit-policy','training-audit-log')]+[{'name':'training-audit-policy','mountPath':'/etc/kubernetes/training-audit-policy.json','readOnly':True},{'name':'training-audit-log','mountPath':'/var/log/training-audit'}]
    put('/etc/kubernetes/training-audit-policy.json',json.dumps(policy));node('mkdir','-p','/var/log/training-audit')
    manifest['metadata'].setdefault('annotations',{})['training.astrona.io/audit-policy']=__import__('hashlib').sha256(json.dumps(policy,sort_keys=True).encode()).hexdigest()
    put('/etc/kubernetes/lab-api-pod.json',json.dumps(manifest));node('mv','/etc/kubernetes/lab-api-pod.json','/etc/kubernetes/manifests/kube-apiserver.yaml')

configure_audit({'apiVersion': 'audit.k8s.io/v1', 'kind': 'Policy', 'omitStages': ['RequestReceived'], 'rules': [{'level': 'Metadata', 'namespaces': ['starfleet'], 'resources': [{'group': '', 'resources': ['secrets', 'configmaps', 'pods', 'pods/exec', 'pods/portforward']}]}, {'level': 'None'}]})
