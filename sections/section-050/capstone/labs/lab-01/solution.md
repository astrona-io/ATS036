---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Investigate Secret, Denied And Exec Access From The Audit Log Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-050)"
test "$(kubectl config current-context)" = "kind-ats-036-capstone-050" || exit 1
node_name="astro-ats-036-capstone-050-control-plane"
worker_name="astro-ats-036-capstone-050-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Keep the provisioned audit Policy. Generate three requests and find their records in the audit log on the control plane node.

1. A successful read of the Secret `audit-token` in `starfleet` as the cluster administrator.
2. A denied read of the same Secret as the ServiceAccount `default` in `outpost`, sent with the `--as` option of `kubectl`. The API server must answer `403`.
3. The command `id` run inside the `shuttle` Pod in `starfleet` with `kubectl exec`.

Create the ConfigMap `audit-investigation` in `starfleet` with these keys: `secretAuditID`, `deniedAuditID` and `execAuditID`, each holding the `auditID` of the matching `ResponseComplete` record; `deniedUser` set to `system:serviceaccount:outpost:default`; `execPod` set to `shuttle`; and `secretName` set to `audit-token`. No record may hold a `requestObject` or `responseObject`, and the Secret value must not appear in the log.

Generate the three requests. The second one fails with a `Forbidden` message, which is the expected result:

```sh
kubectl -n starfleet get secret audit-token -o name
kubectl -n starfleet get secret audit-token --as=system:serviceaccount:outpost:default
kubectl -n starfleet exec shuttle -- id
```

Save this as `record-investigation.py`. It finds the latest matching record for each request and writes the ConfigMap:

```python
import json
import subprocess
import sys

node_name = sys.argv[1]
log = subprocess.run(['podman', 'exec', node_name, 'cat', '/var/log/training-audit/audit.jsonl'], check=True, text=True, capture_output=True).stdout
records = [json.loads(line) for line in log.splitlines() if line.strip()]
complete = [r for r in records if r.get('stage') == 'ResponseComplete']


def latest(test):
    return [r for r in complete if test(r)][-1]['auditID']


def secret_read(record):
    reference = record.get('objectRef', {})
    return reference.get('resource') == 'secrets' and reference.get('name') == 'audit-token' and record['verb'] == 'get'


report = {
    'apiVersion': 'v1',
    'kind': 'ConfigMap',
    'metadata': {'name': 'audit-investigation', 'namespace': 'starfleet'},
    'data': {
        'secretAuditID': latest(lambda r: secret_read(r) and r['responseStatus']['code'] == 200 and 'impersonatedUser' not in r),
        'deniedAuditID': latest(lambda r: secret_read(r) and r['responseStatus']['code'] == 403 and r.get('impersonatedUser', {}).get('username') == 'system:serviceaccount:outpost:default'),
        'execAuditID': latest(lambda r: r.get('objectRef', {}).get('subresource') == 'exec' and r['objectRef'].get('name') == 'shuttle' and 'command=id' in r.get('requestURI', '')),
        'deniedUser': 'system:serviceaccount:outpost:default',
        'execPod': 'shuttle',
        'secretName': 'audit-token',
    },
}
print(json.dumps(report))
```

Run it and apply the result:

```sh
python3 record-investigation.py "$node_name" > configmap-audit-investigation.json
kubectl apply -f configmap-audit-investigation.json
```

## Verify The Result

Check that each identifier names a different record:

```sh
kubectl -n starfleet get configmap audit-investigation -o yaml
podman exec "$node_name" grep -c 'audit-disposable' /var/log/training-audit/audit.jsonl
```

The count must be `0`. The three identifiers must be different, because the requests are different. A report that holds an identifier from the wrong request does not pass.

After recording your result, remove the independent lab with `astrona destroy ats-036-capstone-050`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
