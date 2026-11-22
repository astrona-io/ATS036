def oom_killed():
    status = get('pod', 'memory-hog')['status']['containerStatuses'][0]
    return status.get('lastState', {}).get('terminated', {}).get('reason') == 'OOMKilled'


if wants('impact-report'):
    assert oom_killed(), 'Keep the memory-hog Pod: its OOMKilled status is the evidence'

if wants('workload-limited'):
    container = get('deployment', 'cruncher')['spec']['template']['spec']['containers'][0]
    resources = container.get('resources', {})
    for kind in ('requests', 'limits'):
        assert {'cpu', 'memory'} <= set(resources.get(kind, {})), 'Set CPU and memory ' + kind + ' on the cruncher container'
    assert container['command'] == ['sh', '-c', 'sleep 86400'], 'Keep the cruncher command'
    pods = json.loads(kubectl('get', 'pods', '-n', NAMESPACE, '-l', 'app=cruncher', '-o', 'json'))['items']
    running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and pod['metadata'].get('deletionTimestamp') is None]
    assert running and all(pod['spec']['containers'][0].get('resources', {}).get('limits', {}).get('memory') for pod in running), 'The running cruncher Pods still have no memory limit'

if wants('namespace-defaults'):
    ranges = json.loads(kubectl('get', 'limitranges', '-n', NAMESPACE, '-o', 'json'))['items']
    assert any({'cpu', 'memory'} <= set(item.get('default', {})) for limit_range in ranges for item in limit_range['spec']['limits'] if item.get('type') == 'Container'), 'Create a LimitRange with default CPU and memory limits for containers'
    trial = json.loads(kubectl('run', 'limit-trial', '-n', NAMESPACE, '--image=docker.io/library/busybox:1.37.0', '--restart=Never', '--dry-run=server', '-o', 'json', '--', 'sleep', '1'))
    limits = trial['spec']['containers'][0].get('resources', {}).get('limits', {})
    assert {'cpu', 'memory'} <= set(limits), 'A new container without resources gets no default limits'
