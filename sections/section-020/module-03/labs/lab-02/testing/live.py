import base64


def secret_env(container):
    """Names of the Secrets a container reads through env or envFrom."""
    names = [item.get('valueFrom', {}).get('secretKeyRef', {}).get('name') for item in container.get('env', [])]
    names += [item.get('secretRef', {}).get('name') for item in container.get('envFrom', [])]
    return [name for name in names if name]


if wants('exposure-report'):
    reports = get('pod', 'reports')['spec']
    assert any(volume.get('secret', {}).get('secretName') == 'db-credentials' for volume in reports.get('volumes', [])), 'Preserve Pod reports and its secret volume'
    ledger = get('pod', 'ledger')['spec']['containers'][0]
    assert secret_env(ledger) == ['ledger-token'], 'Preserve Pod ledger and its environment variable'
    report = get('configmap', 'secret-exposure')['data']
    kind, name = report['volumeWorkload'].split('/', 1)
    mounted = get(kind, name)['spec'].get('volumes', [])
    assert any(volume.get('secret', {}).get('secretName') == report['secret'] for volume in mounted), 'Record the workload that mounts the Secret as a volume'

if wants('secret-volume'):
    template = get('deployment', 'billing')['spec']['template']['spec']
    containers = template['containers']
    assert all(not secret_env(container) for container in containers), 'Remove every environment variable of billing that reads a Secret'
    volumes = {volume['name']: volume['secret'] for volume in template.get('volumes', []) if volume.get('secret', {}).get('secretName') == 'db-credentials'}
    assert volumes, 'Mount Secret db-credentials into billing as a secret volume'
    assert all(volume.get('defaultMode') == 0o400 for volume in volumes.values()), 'Set defaultMode 0400 on the secret volume'
    mounts = [mount for container in containers for mount in container.get('volumeMounts', []) if mount['name'] in volumes]
    assert any(mount['mountPath'] == '/etc/db' and mount.get('readOnly') is True for mount in mounts), 'Mount the secret volume read-only at /etc/db'
    expected = base64.b64decode(get('secret', 'db-credentials')['data']['password']).decode()
    value = command(['kubectl', '-n', NAMESPACE, 'exec', 'deploy/billing', '--', 'cat', '/etc/db/password'], success=False)
    assert value.returncode == 0 and value.stdout.strip() == expected, 'The billing container must read the password from /etc/db/password'
    printenv = command(['kubectl', '-n', NAMESPACE, 'exec', 'deploy/billing', '--', 'printenv', 'DB_PASSWORD'], success=False)
    assert printenv.returncode != 0 and not printenv.stdout.strip(), 'The billing container must not have DB_PASSWORD in its environment'
