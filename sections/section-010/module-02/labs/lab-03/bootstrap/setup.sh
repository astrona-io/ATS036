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
sudo kind create cluster --name detection --kubeconfig /etc/training/kubeconfig --image kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f
sudo chmod 0644 /etc/training/kubeconfig
for ns in monitored outside; do
 kubectl create namespace "$ns"
 kubectl -n "$ns" create serviceaccount reporter
 kubectl -n "$ns" run reporter --image=busybox:1.37.0 --overrides='{"spec":{"serviceAccountName":"reporter"}}' -- sleep 36000
 kubectl -n "$ns" wait --for=condition=Ready pod/reporter --timeout=180s
done
sudo helm pull falco --repo https://falcosecurity.github.io/charts --version 9.2.2 --destination /etc/training
sudo tee /etc/training/values.yaml >/dev/null <<'VALUES'
driver:
  kind: modern_ebpf
collectors:
  kubernetes:
    enabled: true
falco:
  json_output: true
  buffered_outputs: false
customRules:
  training.yaml: "- rule: Training namespace shell\n  desc: Unexpected shells in the\
    \ monitored training namespace\n  condition: evt.type in (execve, execveat) and\
    \ evt.dir = < and proc.name in (sh, bash) and k8smeta.ns.name = unfinished and\
    \ not proc.cmdline contains approved-\n  output: Training shell (command=%proc.cmdline\
    \ namespace=%k8smeta.ns.name pod=%k8smeta.pod.name uid=%k8smeta.pod.uid)\n  priority:\
    \ WARNING\n"
VALUES
sudo chmod 0666 /etc/training/values.yaml
sudo helm --kubeconfig /etc/training/kubeconfig install falco /etc/training/falco-9.2.2.tgz -n falco --create-namespace -f /etc/training/values.yaml --wait --timeout=10m
kubectl -n falco rollout status daemonset/falco --timeout=300s
sleep 15

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
    k('-n','falco','rollout','status','daemonset/falco','--timeout=30s')
    nonce=uuid.uuid4().hex
    pod=get('pod','reporter','monitored');uid=pod['metadata']['uid']
    cases=[('monitored','unexpected-'+nonce),('monitored','approved-'+nonce),('outside','outside-'+nonce),('monitored','later-'+nonce)]
    for ns,marker in cases:
        k('-n',ns,'exec','reporter','--','sh','-c','sleep 0.2',marker)
    time.sleep(8)
    logs=k('-n','falco','logs','-l','app.kubernetes.io/name=falco','-c','falco','--since=30s','--tail=-1')
    events=[]
    for line in logs.splitlines():
        try: event=json.loads(line)
        except ValueError: continue
        if nonce in event.get('output','') and event.get('rule')=='Training namespace shell': events.append(event)
    for marker in ('unexpected-','later-'):
        matching=[e for e in events if marker+nonce in e['output']]
        assert matching, 'Detect both fresh protected shell events'
        for event in matching:
            fields=event['output_fields']
            assert fields.get('k8smeta.ns.name')=='monitored' and fields.get('k8smeta.pod.name')=='reporter' and fields.get('k8smeta.pod.uid')==uid, 'Attach the live Kubernetes namespace, Pod name and UID'
    if outcome=='scoped-exceptions':
        assert not any('approved-'+nonce in e['output'] for e in events), 'Exclude the approved command without silencing other shells'
        assert not any('outside-'+nonce in e['output'] for e in events), 'Exclude the outside namespace'
    elif outcome!='namespace-detection': raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
