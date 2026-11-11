---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Find The Audit Record Of A Pod Exec Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-03-01" || exit 1
node_name="astro-ats-036-lab-010-03-01-control-plane"
worker_name="astro-ats-036-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The API server writes an audit log at Metadata level for Pods, Pod `exec` and `portforward` requests, ConfigMaps and Secrets in the starfleet-036-010-03-01 namespace. Setup has already run one `kubectl exec` into a probe Pod. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-036-010-03-01 get pods -o wide
kubectl get nodes -o wide
```

Read the audit log on the control-plane node container of this environment. An `exec` request is a `create` on the `pods` resource with the subresource `exec`, so filter on those fields and look at which `stage` values appear for the request.

Save this as `configmap-exec-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: exec-finding
  namespace: starfleet-036-010-03-01
data:
  verb: create
  resource: pods
  subresource: exec
  namespace: starfleet-036-010-03-01
  finding: unexpected-exec
```

Save this as `record-audit.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-lab-010-03-01"
NODE="astro-ats-036-lab-010-03-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-lab-010-03-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
matching=[record for record in records if record.get('verb') in ('create','get') and record.get('objectRef',{}).get('resource')=='pods' and record.get('objectRef',{}).get('subresource')=='exec' and record.get('objectRef',{}).get('namespace')=='starfleet-036-010-03-01' and record.get('objectRef',{}).get('name','').startswith('probe-') and record.get('stage') in ('ResponseStarted','ResponseComplete')]
assert matching, 'Wait for a real exec audit record'
record=matching[0]
report_name='exec-finding';report={'actor':record['user']['username'],'verb':record['verb'],'resource':record['objectRef']['resource'],'subresource':record['objectRef']['subresource'],'namespace':record['objectRef']['namespace'],'podName':record['objectRef']['name'],'finding':'unexpected-exec','auditID':record['auditID'],'stage':record['stage'],'requestURI':record['requestURI']}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet-036-010-03-01'},'data':report}))
    run('kubectl','apply','-f',str(source))
```

Apply the scoped correction:

```sh
python3 record-audit.py
```


## Verify The Result

Read the report back and compare it with the audit record.

```sh
kubectl -n starfleet-036-010-03-01 get configmap exec-finding -o yaml
kubectl -n starfleet-036-010-03-01 get deployment probe
```

The report names the authenticated user that sent the request, not the person at the keyboard, and not the command that ran inside the container. The `requestURI` carries the requested command as `command=` query parameters.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-010-03-01`.

## Common pitfalls

> [!WARNING]
> An audit record of an `exec` request proves that someone asked the API server to run a command. It does not show the command output or what the process did. Keep the `auditID` and the `stage` so the report maps to one real record.
