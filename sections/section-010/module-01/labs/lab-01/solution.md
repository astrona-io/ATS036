---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Detect A Denied API Access Attempt Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-01-01" || exit 1
node_name="astro-ats-036-lab-010-01-01-control-plane"
worker_name="astro-ats-036-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-036-010-01-01 get pods -o wide
kubectl get nodes -o wide
```

Use the API audit log to identify the threat-reader ServiceAccount request denied with status 403 for the disposable audit-token Secret. Create audit-finding with actor, resource, namespace, code, finding unauthorized-secret-read, auditID, stage and requestURI matching the actual record. Keep the credential body out of the report. This is API behavioral evidence; it does not claim kernel-level syscall detection or establish a complete attack timeline from one event.

Save this as `configmap-audit-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-finding
  namespace: starfleet-036-010-01-01
data:
  actor: system:serviceaccount:starfleet-036-010-01-01:threat-reader
  resource: secrets
  namespace: starfleet-036-010-01-01
  code: '403'
  finding: unauthorized-secret-read
```

Save this as `record-audit.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-036-lab-010-01-01"
NODE="astro-ats-036-lab-010-01-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-036-lab-010-01-01', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

records=[json.loads(line) for line in node('cat','/var/log/training-audit/audit.jsonl').splitlines() if line.strip()]
matching=[record for record in records if record.get('stage')=='ResponseComplete' and record.get('user',{}).get('username')=='system:serviceaccount:starfleet-036-010-01-01:threat-reader' and record.get('objectRef',{}).get('resource')=='secrets' and record.get('objectRef',{}).get('namespace')=='starfleet-036-010-01-01' and record.get('responseStatus',{}).get('code')==403]
assert matching, 'Wait for a real denied API record'
record=matching[-1]
report_name='audit-finding';report={'actor':record['user']['username'],'resource':record['objectRef']['resource'],'namespace':record['objectRef']['namespace'],'code':str(record['responseStatus']['code']),'finding':'unauthorized-secret-read','auditID':record['auditID'],'stage':record['stage'],'requestURI':record['requestURI']}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet-036-010-01-01'},'data':report}))
    run('kubectl','apply','-f',str(source))

```

Apply the scoped correction:

```sh
python3 record-audit.py
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet-036-010-01-01 get configmaps
kubectl -n starfleet-036-010-01-01 get deployment probe -o yaml
```

Classify a real denied Secret request and bind the finding to its actor and audit identifier. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-036-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> A denied request does not prove data was read. Attribute the authenticated user and request outcome, not a guessed Pod name. Preserve auditID and stage so the report maps to a real record.
