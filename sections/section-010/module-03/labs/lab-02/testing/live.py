from urllib.parse import parse_qs, urlsplit


def correlation(*keys):
    data = get('configmap', 'exec-correlation').get('data') or {}
    missing = [key for key in keys if not data.get(key)]
    assert not missing, 'ConfigMap exec-correlation is missing keys: ' + ', '.join(missing)
    return data


def exec_record(audit_id):
    """The first audit event with this auditID; it must be a pods/exec request in the lab namespace."""
    for line in node_exec(NODE, 'cat', '/var/log/training-audit/audit.jsonl').stdout.splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if record.get('auditID') == audit_id:
            reference = record.get('objectRef', {})
            assert reference.get('resource') == 'pods' and reference.get('subresource') == 'exec', 'The recorded auditID is not a pods/exec request'
            assert reference.get('namespace') == NAMESPACE, 'The recorded exec request is not in ' + NAMESPACE
            return record
    raise AssertionError('No audit event has the recorded auditID')


def exec_container(record):
    names = parse_qs(urlsplit(record.get('requestURI', '')).query).get('container', [])
    assert len(names) == 1, 'The exec request does not name one container'
    return names[0]


if wants('exec-record'):
    data = correlation('auditID', 'podName', 'container')
    record = exec_record(data['auditID'])
    assert record['objectRef'].get('name') == data['podName'], 'podName is not the Pod that received the exec request'
    assert data['podName'].startswith('probe-'), 'Name the probe Pod that received the exec request'
    get('pod', data['podName'])
    assert data['container'] == exec_container(record), 'container is not the container named in the exec request'

if wants('runtime-location'):
    data = correlation('auditID', 'nodeName', 'containerID')
    record = exec_record(data['auditID'])
    pod = get('pod', record['objectRef']['name'])
    assert pod['spec'].get('nodeName') == data['nodeName'], 'nodeName is not the node that runs the Pod'
    container = exec_container(record)
    status = next((item for item in pod.get('status', {}).get('containerStatuses', []) if item['name'] == container), None)
    assert status and status.get('containerID'), 'The exec target container has no container ID yet'
    assert data['containerID'].startswith('containerd://'), 'Record the full containerID with its containerd:// prefix'
    assert data['containerID'] == status['containerID'], 'containerID is not the ID of the exec target container'
