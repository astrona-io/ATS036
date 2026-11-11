import os
import json
import subprocess
import sys

node_name = sys.argv[1]


def on_node(*args):
    return subprocess.run([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"), 'exec', node_name, *args], check=True, text=True, capture_output=True).stdout.strip()


manifest = json.loads(on_node('cat', '/etc/kubernetes/manifests/kube-apiserver.yaml'))
flags = dict(arg[2:].split('=', 1) for arg in manifest['spec']['containers'][0]['command'] if arg.startswith('--audit-') and '=' in arg)
report = {
    'apiVersion': 'v1',
    'kind': 'ConfigMap',
    'metadata': {'name': 'audit-retention', 'namespace': 'starfleet-036-050-03-01'},
    'data': {
        'policyFile': flags['audit-policy-file'],
        'logPath': flags['audit-log-path'],
        'maxAge': flags['audit-log-maxage'],
        'maxBackup': flags['audit-log-maxbackup'],
        'maxSize': flags['audit-log-maxsize'],
        'logMode': on_node('stat', '-c', '%a', flags['audit-log-path']),
    },
}
print(json.dumps(report))
