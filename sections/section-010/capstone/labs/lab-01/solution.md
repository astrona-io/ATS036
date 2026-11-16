---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Report And Contain Suspicious Behavior From Audit Evidence Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-010)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-010" || exit 1
node_name="astro-ats-036-capstone-010-control-plane"
worker_name="astro-ats-036-capstone-010-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and three Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet namespace. Setup has produced two events: the threat-reader ServiceAccount asked for the audit-token Secret and was denied, and one `kubectl exec` ran a command in a probe Pod. Nothing has been reported or contained yet.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods --show-labels -o wide
kubectl -n starfleet get endpoints probe
```

Read the audit log on the control-plane node container of this environment. Find the two records first, then relabel the Pod. The Deployment selects its Pods by the labels `app` and `release`, so a Pod without them is no longer counted, and the Deployment starts a replacement.

Save this as `configmap-incident-report.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-report
  namespace: starfleet
data:
  response: quarantined
```

Save this as `record-audit.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-capstone-010"
NODE="astro-ats-036-capstone-010-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-capstone-010', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
denied=[r for r in records if r.get('stage')=='ResponseComplete' and r.get('user',{}).get('username')=='system:serviceaccount:starfleet:threat-reader' and r.get('objectRef',{}).get('resource')=='secrets' and r.get('responseStatus',{}).get('code')==403]
execs=[r for r in records if r.get('verb') in ('create','get') and r.get('objectRef',{}).get('subresource')=='exec' and r.get('objectRef',{}).get('namespace')=='starfleet' and r.get('objectRef',{}).get('name','').startswith('probe-') and r.get('stage') in ('ResponseStarted','ResponseComplete')]
assert denied and execs, 'Wait for the real audit records'
denied_record=denied[-1]; exec_record=execs[0]
pod_name=exec_record['objectRef']['name']
report={'deniedActor':denied_record['user']['username'],'deniedAuditID':denied_record['auditID'],'execActor':exec_record['user']['username'],'execAuditID':exec_record['auditID'],'execStage':exec_record['stage'],'podName':pod_name,'response':'quarantined'}
with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'incident-report','namespace':'starfleet'},'data':report}))
    run('kubectl','apply','-f',str(source))
run('kubectl','-n','starfleet','label','pod',pod_name,'app-','release-','quarantine=true','--overwrite')
```

Apply the scoped correction. The script writes the report and relabels the Pod:

```sh
python3 record-audit.py
```


## Verify The Result

Check the report, the labels and the replacement replica.

```sh
kubectl -n starfleet get configmap incident-report -o yaml
kubectl -n starfleet get pods --show-labels
kubectl -n starfleet get endpoints probe
```

The quarantined Pod keeps running with the label `quarantine=true`, and the endpoints of the probe Service list only the other replicas. Containment removes the Pod from traffic. It does not remove the cause, so the Pod stays available for evidence collection.

After recording your result, remove the independent lab with `astrona destroy ats-036-capstone-010`.

## Common pitfalls

> [!WARNING]
> Deleting the Pod destroys the process list, the filesystem and the container logs that an investigation needs. A denied request proves a denial, not a read, and an `exec` record proves a request, not the command output.
