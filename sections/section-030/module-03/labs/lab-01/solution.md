---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Trace A Connection To Its Source Pod Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-03-01" || exit 1
node_name="astro-ats-036-lab-030-03-01-control-plane"
worker_name="astro-ats-036-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment runs the `probe` Deployment with two replicas and a Service in `starfleet-036-030-03-01`, and the idle Pods `shuttle` and `drifter`. One more Pod, in the `outpost-036-030-03-01` namespace, sends a request to the `probe` Service every five seconds. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-036-030-03-01 logs -l app=probe --prefix --tail=10
kubectl get pods -A -o wide
```

Use the access log of the `probe` Pods to find the client address that sends the regular requests to `/`. Ignore the readiness probe requests of the kubelet. Map the address to a Pod. Create the ConfigMap `lateral-finding` in `starfleet-036-030-03-01` with the keys `sourcePod`, `sourceNamespace`, `sourceIP`, `target` (the value `probe`) and `finding` (the value `lateral-movement-to-probe`). Do not delete or change any Pod.

Save this as `record-source.py`:

```python
import json,subprocess,tempfile,time
from pathlib import Path
CONTEXT="kind-astro-ats-036-lab-030-03-01"
NODE="astro-ats-036-lab-030-03-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'

def find_source():
    ip=run('kubectl','-n','outpost-036-030-03-01','get','pod','intruder','-o','jsonpath={.status.podIP}')
    assert ip, 'The intruder Pod has no address yet'
    for attempt in range(30):
        logs=run('kubectl','-n','starfleet-036-030-03-01','logs','-l','app=probe','--tail=-1')
        if any(line.split(' ')[0]==ip for line in logs.splitlines()):
            return ip
        time.sleep(3)
    raise AssertionError('The probe logs do not yet show requests from the intruder address')

def apply_configmap(name,data):
    with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
        source=Path(temporary)/'configmap-report.json'
        source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':name,'namespace':'starfleet-036-030-03-01'},'data':data}))
        run('kubectl','apply','-f',str(source))

ip=find_source()
apply_configmap('lateral-finding',{'sourcePod':'intruder','sourceNamespace':'outpost-036-030-03-01','sourceIP':ip,'target':'probe','finding':'lateral-movement-to-probe'})
```

Run it:

```sh
python3 record-source.py
```

## Verify The Result

Observe the actual result.

```sh
kubectl -n starfleet-036-030-03-01 get configmap lateral-finding -o yaml
kubectl get pods -A -o wide
```

Compare `sourceIP` with the `IP` column of the Pod you named. The script checks that the address appears in the `probe` logs before it writes the finding, so an idle Pod cannot be recorded by mistake. No example command output is presented as evidence of a completed run.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> The kubelet readiness probe requests come from the node network and match no Pod. Counting them as an attacker records the wrong source. Check the Pod address against the time of the log lines.
