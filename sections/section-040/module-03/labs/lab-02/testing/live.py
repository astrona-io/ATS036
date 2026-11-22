HOST_DIRECTORY = '/var/lib/training-036-040-03-02'
APPROVED_CONTENT = 'approved-settings-v1'


def collector_pods():
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=collector', '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert pods, 'No collector Pod is running'
    return pods


def pod_exec(pod_name, *args):
    return command(['kubectl', '-n', NAMESPACE, 'exec', pod_name, '-c', 'collector', '--', *args], success=False)


if wants('host-write-blocked'):
    for pod in collector_pods():
        name = pod['metadata']['name']
        assert pod['status'].get('phase') == 'Running', 'Collector Pod is not running: ' + name
        volume = next((item for item in pod['spec'].get('volumes', []) if item['name'] == 'node-data'), {})
        assert volume.get('hostPath', {}).get('path') == HOST_DIRECTORY, 'Keep the node-data hostPath volume so the collector can read the node file'
        node = pod['spec'].get('nodeName')
        assert node in (NODE, WORKER), 'Collector Pod runs on a node outside this lab: ' + str(node)
        read = pod_exec(name, 'cat', '/host-data/approved.txt')
        assert read.returncode == 0 and read.stdout.strip() == APPROVED_CONTENT, 'Pod ' + name + ' must still read /host-data/approved.txt'
        write = pod_exec(name, 'sh', '-c', 'printf grader > /host-data/grader-write-test')
        if write.returncode == 0:
            pod_exec(name, 'rm', '-f', '/host-data/grader-write-test')
            raise AssertionError('Pod ' + name + ' can still write to the hostPath volume')
        assert 'read-only file system' in (write.stdout + write.stderr).lower(), 'The write must fail because the mount is read-only'
        on_node = node_exec(node, 'test', '-e', HOST_DIRECTORY + '/grader-write-test', success=False)
        assert on_node.returncode != 0, 'A file written by the grader reached ' + HOST_DIRECTORY + ' on the node'
        node_file = node_exec(node, 'cat', HOST_DIRECTORY + '/approved.txt', success=False)
        assert node_file.stdout.strip() == APPROVED_CONTENT, 'The approved file on the node changed'
