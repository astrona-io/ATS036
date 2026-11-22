EVIDENCE_COMMAND = ['sh', '-c', 'printf "application-started\\n"; if [ ! -f /state/crashed ]; then read token < /proc/sys/kernel/random/uuid; printf "crash-token=%s\\n" "$token"; touch /state/crashed; sleep 2; exit 12; fi; sleep 86400']


def evidence_pod():
    pod = get('pod', 'crash-report')
    assert pod['spec']['containers'][0].get('command') == EVIDENCE_COMMAND, 'Preserve the evidence Pod crash-report'
    status = next((item for item in pod.get('status', {}).get('containerStatuses', []) if item['name'] == 'report'), None)
    assert status and status.get('restartCount', 0) >= 1, 'Container report must have a previous instance'
    return pod, status


def pod_node(pod):
    """The node container that runs the Pod: the worker or the control plane of this lab."""
    name = pod['spec'].get('nodeName')
    if name == WORKER:
        return WORKER
    if name == NODE:
        return NODE
    raise AssertionError('Pod crash-report runs on a node outside this lab')


def evidence(*keys):
    data = get('configmap', 'node-log-evidence').get('data') or {}
    missing = [key for key in keys if not data.get(key)]
    assert not missing, 'ConfigMap node-log-evidence is missing keys: ' + ', '.join(missing)
    return data


def log_directory(pod):
    return '/var/log/pods/{}_{}_{}'.format(NAMESPACE, pod['metadata']['name'], pod['metadata']['uid'])


if wants('pod-log-directory'):
    data = evidence('nodeName', 'podUID', 'logDirectory')
    pod, status = evidence_pod()
    assert data['nodeName'] == pod['spec'].get('nodeName'), 'nodeName is not the node that runs crash-report'
    assert data['podUID'] == pod['metadata']['uid'], 'podUID is not the UID of crash-report in ' + NAMESPACE
    expected = log_directory(pod)
    assert data['logDirectory'].rstrip('/') == expected, 'logDirectory is not the Pod log directory under /var/log/pods'
    assert node_exec(pod_node(pod), 'test', '-d', expected, success=False).returncode == 0, 'The Pod log directory is missing on the node'

if wants('instance-log-files'):
    data = evidence('logFiles', 'crashToken')
    pod, status = evidence_pod()
    node = pod_node(pod)
    directory = log_directory(pod) + '/report'
    files = sorted(node_exec(node, 'ls', directory).stdout.split())
    assert len(files) >= 2, 'The node keeps fewer than two log files for container report'
    recorded = sorted(name.strip() for name in data['logFiles'].split(',') if name.strip())
    assert recorded == files, 'logFiles does not list the files in the report container directory on the node'
    previous = '{}/{}.log'.format(directory, status['restartCount'] - 1)
    tokens = [line.split('crash-token=', 1)[1].strip() for line in node_exec(node, 'cat', previous).stdout.splitlines() if 'crash-token=' in line]
    assert tokens, 'The previous instance log file has no crash-token line'
    assert data['crashToken'].strip() == tokens[0], 'crashToken is not the token in the previous instance log file'
