#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl python3 ca-certificates tcpdump wireguard-tools
sudo systemctl enable --now docker
case "$(uname -m)" in
 x86_64) arch=amd64; helm_sha=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b ;;
 aarch64) arch=arm64; helm_sha=8cf8f66ecbc252ac8f7f06cca68aba88508ddfde3a6a34feb1678ad1694b4f88 ;;
 *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-$arch" -o /tmp/kind
curl -fL --retry 3 --max-time 30 "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-$arch.sha256sum" -o /tmp/kind.sha256
printf '%s  /tmp/kind\n' "$(cut -d' ' -f1 /tmp/kind.sha256)" | sha256sum -c -
sudo install -m 0755 /tmp/kind /usr/local/bin/kind
curl -fL --retry 3 --max-time 180 "https://dl.k8s.io/release/v1.35.0/bin/linux/$arch/kubectl" -o /tmp/kubectl
curl -fL --retry 3 --max-time 30 "https://dl.k8s.io/release/v1.35.0/bin/linux/$arch/kubectl.sha256" -o /tmp/kubectl.sha256
printf '%s  /tmp/kubectl\n' "$(cat /tmp/kubectl.sha256)" | sha256sum -c -
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
curl -fL --retry 3 --max-time 180 "https://get.helm.sh/helm-v4.3.1-linux-$arch.tar.gz" -o /tmp/helm.tar.gz
printf '%s  /tmp/helm.tar.gz\n' "$helm_sha" | sha256sum -c -
tar -xzf /tmp/helm.tar.gz -C /tmp
sudo install -m 0755 "/tmp/linux-$arch/helm" /usr/local/bin/helm
sudo install -d -m 0755 /etc/training
export KUBECONFIG=/etc/training/kubeconfig
sudo kind create cluster --name auditing --kubeconfig /etc/training/kubeconfig --image kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f
sudo chmod 0644 /etc/training/kubeconfig
kubectl create namespace audited
kubectl create namespace outside
gateway=$(sudo docker network inspect kind | python3 -c 'import ipaddress,json,sys; print(next(c["Gateway"] for c in json.load(sys.stdin)[0]["IPAM"]["Config"] if ipaddress.ip_address(c["Gateway"]).version == 4))')
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 2 -keyout /etc/training/collector.key -out /etc/training/collector.crt -subj /CN=audit-collector -addext "subjectAltName=IP:$gateway" >/dev/null 2>&1
sudo install -d /var/log/training-audit
sudo touch /var/log/training-audit/events.jsonl
sudo tee /etc/training/collector.py >/dev/null <<'COLLECTOR'
import http.server,json,ssl,pathlib
class Handler(http.server.BaseHTTPRequestHandler):
 def do_POST(self):
  if self.headers.get('Authorization')!='Bearer training-audit-token':
   self.send_response(401);self.end_headers();return
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  with open('/var/log/training-audit/events.jsonl','a') as file:
   for event in body.get('items',[]): file.write(json.dumps(event)+'\n')
  self.send_response(200);self.end_headers();self.wfile.write(b'{}')
 def log_message(self,*args): pass
httpd=http.server.HTTPServer(('0.0.0.0',8443),Handler)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain('/etc/training/collector.crt','/etc/training/collector.key')
httpd.socket=ctx.wrap_socket(httpd.socket,server_side=True);httpd.serve_forever()
COLLECTOR
sudo tee /etc/systemd/system/training-audit-collector.service >/dev/null <<'UNIT'
[Unit]
Description=Isolated audit delivery receiver
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /etc/training/collector.py
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now training-audit-collector
sudo python3 - "$gateway" <<'CONFIG'
import base64,json,pathlib,sys
root=pathlib.Path('/etc/training')
config={'apiVersion':'v1','kind':'Config','clusters':[{'name':'collector','cluster':{'server':'https://'+sys.argv[1]+':8443/audit','certificate-authority-data':base64.b64encode((root/'collector.crt').read_bytes()).decode()}}],'users':[{'name':'audit','user':{'token':'incorrect-token'}}],'contexts':[{'name':'collector','context':{'cluster':'collector','user':'audit'}}],'current-context':'collector'}
(root/'audit-webhook.json').write_text(json.dumps(config,indent=2)+'\n')
(root/'audit-policy.json').write_text(json.dumps({'apiVersion':'audit.k8s.io/v1','kind':'Policy','rules':[{'level':'None'}]},indent=2)+'\n')
CONFIG
sudo tee /usr/local/bin/reload-training-audit >/dev/null <<'RELOAD'
#!/usr/bin/env python3
import hashlib,json,os,pathlib,subprocess,tempfile,time
os.environ['KUBECONFIG']='/etc/training/kubeconfig'
node='auditing-control-plane'
def run(*args): return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT,timeout=30).strip()
assert run('docker','inspect',node,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='auditing', 'Wrong node'
policy=json.loads(pathlib.Path('/etc/training/audit-policy.json').read_text())
webhook=json.loads(pathlib.Path('/etc/training/audit-webhook.json').read_text())
for name in ('audit-policy.json','audit-webhook.json'):
 run('docker','cp','/etc/training/'+name,node+':/etc/kubernetes/'+name)
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp)/'api.yaml';p.write_text(run('docker','exec',node,'cat','/etc/kubernetes/manifests/kube-apiserver.yaml'))
 manifest=json.loads(run('kubectl','create','--dry-run=client','--validate=false','-f',str(p),'-o','json'))
container=manifest['spec']['containers'][0]
previous=json.loads(run('kubectl','-n','kube-system','get','pod','kube-apiserver-'+node,'-o','json'))
old_id=previous.get('status',{}).get('containerStatuses',[{}])[0].get('containerID')
flags={'audit-policy-file':'/etc/kubernetes/audit-policy.json','audit-webhook-config-file':'/etc/kubernetes/audit-webhook.json','audit-webhook-mode':'batch','audit-webhook-batch-max-wait':'1s','audit-webhook-version':'audit.k8s.io/v1'}
container['command']=[a for a in container['command'] if not any(a.startswith('--'+f+'=') for f in flags)]+['--'+f+'='+v for f,v in flags.items()]
for name in ('audit-policy','audit-webhook'):
 manifest['spec']['volumes']=[v for v in manifest['spec'].get('volumes',[]) if v['name']!=name]+[{'name':name,'hostPath':{'path':'/etc/kubernetes/'+name+'.json','type':'File'}}]
 container['volumeMounts']=[v for v in container.get('volumeMounts',[]) if v['name']!=name]+[{'name':name,'mountPath':'/etc/kubernetes/'+name+'.json','readOnly':True}]
revision=hashlib.sha256(json.dumps([policy,webhook],sort_keys=True).encode()).hexdigest()
manifest['metadata'].setdefault('annotations',{})['training.astrona.io/audit-revision']=revision
# A container-spec change forces the process to reload its mounted audit inputs.
container['env']=[e for e in container.get('env',[]) if e['name']!='TRAINING_AUDIT_REVISION']+[{'name':'TRAINING_AUDIT_REVISION','value':revision}]
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp)/'api.json';p.write_text(json.dumps(manifest));run('docker','cp',str(p),node+':/etc/kubernetes/replacement-api.json')
run('docker','exec',node,'mv','/etc/kubernetes/replacement-api.json','/etc/kubernetes/manifests/kube-apiserver.yaml')
for attempt in range(90):
 try:
  pod=json.loads(run('kubectl','--request-timeout=3s','-n','kube-system','get','pod','kube-apiserver-'+node,'-o','json'))
  if pod.get('status',{}).get('containerStatuses',[{}])[0].get('containerID')!=old_id and pod['metadata'].get('annotations',{}).get('training.astrona.io/audit-revision')==revision and any(c.get('type')=='Ready' and c.get('status')=='True' for c in pod.get('status',{}).get('conditions',[])) and run('kubectl','--request-timeout=3s','get','--raw=/readyz')=='ok': break
 except (subprocess.SubprocessError,ValueError,KeyError): pass
 time.sleep(2)
else: raise RuntimeError('Replacement API server did not become ready')
RELOAD
sudo chmod 0755 /usr/local/bin/reload-training-audit
sudo chmod 0666 /etc/training/audit-policy.json /etc/training/audit-webhook.json
sudo reload-training-audit

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import json,os,pathlib,subprocess,sys,time,uuid,tempfile
os.environ['KUBECONFIG']='/etc/training/kubeconfig'
def run(args,timeout=60): return subprocess.run(args,text=True,capture_output=True,timeout=timeout)
def k(*args):
    result=run(['kubectl',*args])
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout
def get(kind,name,namespace=None):
    return json.loads(k(*(['-n',namespace] if namespace else []),'get',kind,name,'-o','json'))

def check(outcome):
    webhook=json.loads(pathlib.Path('/etc/training/audit-webhook.json').read_text())
    assert webhook['users'][0]['user']['token']=='training-audit-token', 'Configure the collector credential'
    assert webhook['clusters'][0]['cluster'].get('certificate-authority-data') and not webhook['clusters'][0]['cluster'].get('insecure-skip-tls-verify'), 'Verify the collector TLS certificate'
    active=run(['systemctl','is-active','training-audit-collector'])
    if active.returncode: raise RuntimeError('The independent collector must remain healthy')
    nonce=uuid.uuid4().hex;secret='training-body-'+nonce
    probes=[(ns,kind,ns+'-'+kind.lower()+'-'+nonce) for ns in ('audited','outside') for kind in ('Secret','ConfigMap')]
    log=pathlib.Path('/var/log/training-audit/events.jsonl');offset=log.stat().st_size
    created=[]
    try:
        for ns,kind,name in probes:
            obj={'apiVersion':'v1','kind':kind,'metadata':{'name':name,'namespace':ns},('stringData' if kind=='Secret' else 'data'):{'value':secret}}
            result=subprocess.run(['kubectl','create','-f','-'],input=json.dumps(obj),text=True,capture_output=True,timeout=30)
            if result.returncode: raise RuntimeError(result.stderr)
            created.append((ns,kind,name))
        deadline=time.monotonic()+12
        events=[]
        while time.monotonic()<deadline:
            time.sleep(1)
            with log.open() as file:
                file.seek(offset); lines=file.readlines()
            events=[json.loads(line) for line in lines if line.strip()]
        expected=[]
        for ns,kind,name in probes[:2]:
            matching=[e for e in events if e.get('objectRef',{}).get('name')==name and e.get('verb')=='create' and e.get('stage')=='ResponseComplete']
            if not matching:
                print(k('-n','kube-system','logs','kube-apiserver-auditing-control-plane','--tail=35'))
                print(run(['journalctl','-u','training-audit-collector','--no-pager','-n','20']).stdout)
            assert matching, 'Deliver the fresh scoped create event to the external collector'
            for event in matching:
                assert event.get('auditID') and event.get('user',{}).get('username') and event['objectRef'].get('namespace')==ns and event['objectRef'].get('resource')==kind.lower()+'s' and event.get('responseStatus',{}).get('code')==201, 'Preserve event identity, resource and successful response metadata'
            expected.extend(matching)
        if outcome=='metadata-boundary':
            assert all(e.get('level')=='Metadata' and 'requestObject' not in e and 'responseObject' not in e for e in expected), 'Keep Secret request and response bodies out of the receiver'
            assert not any(e.get('objectRef',{}).get('name') in {p[2] for p in probes[2:]} for e in events), 'Do not forward the outside namespace'
            assert secret not in ''.join(lines), 'Never forward Secret values'
        elif outcome!='remote-delivery': raise RuntimeError('Unknown outcome')
    finally:
        for ns,kind,name in created: k('-n',ns,'delete',kind,name,'--ignore-not-found')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
