---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Investigate And Contain A Multi-Phase Incident Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-030" || exit 1
node_name="astro-ats-036-capstone-030-control-plane"
worker_name="astro-ats-036-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has the `probe` Deployment, the `shuttle` and `drifter` Pods, and the `threat-client` Pod that is denied when it reads the Secret `audit-token`. Three things are unexplained: the `cache-sync` Deployment in `starfleet`, which runs as the `build-helper` ServiceAccount; the RoleBinding that gives that ServiceAccount its permissions; and a Pod in `outpost` that sends a request to the `probe` Service every five seconds. The API server writes an audit log on the control plane node. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods,deployments,rolebindings -o wide
kubectl get pods -A -o wide
kubectl -n starfleet logs -l app=probe --prefix --tail=10
```

Create the ConfigMap `incident-report` in `starfleet` with these keys: `actor` and `auditID` of the real audit record for the denied Secret read of `threat-reader`; `deployment` and `binding` of the persistence objects; `sourcePod`, `sourceNamespace` and `sourceIP` of the Pod that sends regular requests to the `probe` Service; `phases` with the value `credential-access,persistence,lateral-movement`; and `finding` with the value `multi-phase-incident`. Keep the content of the Secret out of the report. Then contain the incident: scale `cache-sync` to zero replicas, delete the RoleBinding of the incident, and label the intruding Pod `incident=quarantine` without deleting it. Do not delete the Secret `audit-token`, the `probe` Deployment or the RoleBinding `probe-reader-view`.

Save this as `record-incident.py`. It finds the audit record and the source address from the real evidence:

```python
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
```

Run it:

```sh
python3 record-incident.py
```

Contain the workload, the authority and the intruding Pod:

```sh
kubectl -n starfleet scale deployment/cache-sync --replicas=0
kubectl -n starfleet delete rolebinding build-helper-edit
kubectl -n outpost label pod intruder incident=quarantine
```

## Verify The Result

Observe the actual result.

```sh
kubectl -n starfleet get configmap incident-report -o yaml
kubectl -n starfleet get pods,rolebindings
kubectl -n outpost get pod intruder --show-labels
```

The report must match the audit record, the owner chain and the log evidence. The labelled Pod keeps running so its state stays available for the investigation. No example command output is presented as evidence of a completed run.

After recording your result, remove the independent lab with `astrona destroy ats-036-capstone-030`.

## Common pitfalls

> [!WARNING]
> Do not delete the intruding Pod or the Deployment before the report is written. Deleting removes the evidence and, for the Deployment, the template. A denied Secret read does not prove data was read: record the denial as it is.
