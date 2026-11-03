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
