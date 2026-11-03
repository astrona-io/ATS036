---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Guided Practice: Record The Audit Retention Settings And Log File Protection

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-050-03)"
test "$(kubectl config current-context)" = "kind-ats-036-playground-050-03" || exit 1
node_name="astro-ats-036-playground-050-03-control-plane"
worker_name="astro-ats-036-playground-050-03-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Keep the provisioned audit configuration. Read the audit flags from the `kube-apiserver` static Pod manifest on the control plane node and the permission mode of the audit log file. Create the ConfigMap `audit-retention` in `starfleet` with `policyFile`, `logPath`, `maxAge`, `maxBackup`, `maxSize` and `logMode`. The values must match the live manifest and the live file: `policyFile` and `logPath` are the paths from the flags, `maxAge` is in days, `maxBackup` is a count of files, `maxSize` is in megabytes and `logMode` is the octal mode printed by `stat -c %a`. Do not change the API server.

Read the audit flags and the file mode on the control plane node:

```sh
podman exec "$node_name" grep -o -- '--audit-[a-z-]*=[^"]*' /etc/kubernetes/manifests/kube-apiserver.yaml
podman exec "$node_name" stat -c '%a %U %n' /var/log/training-audit/audit.jsonl
```

Save this as `record-retention.py`. It reads both sources and writes the ConfigMap, so no value is typed by hand:

```python
import json
import subprocess
import sys

node_name = sys.argv[1]


def on_node(*args):
    return subprocess.run(['podman', 'exec', node_name, *args], check=True, text=True, capture_output=True).stdout.strip()


manifest = json.loads(on_node('cat', '/etc/kubernetes/manifests/kube-apiserver.yaml'))
flags = dict(arg[2:].split('=', 1) for arg in manifest['spec']['containers'][0]['command'] if arg.startswith('--audit-') and '=' in arg)
report = {
    'apiVersion': 'v1',
    'kind': 'ConfigMap',
    'metadata': {'name': 'audit-retention', 'namespace': 'starfleet'},
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
```

Run it and apply the result:

```sh
python3 record-retention.py "$node_name" > configmap-audit-retention.json
kubectl apply -f configmap-audit-retention.json
```

## Verify The Result

Compare the report with the node:

```sh
kubectl -n starfleet get configmap audit-retention -o yaml
podman exec "$node_name" ls -l /var/log/training-audit
```

The `logMode` in the ConfigMap must equal the mode in the `stat` output. A report copied from the reading instead of the node can differ from the live values.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
