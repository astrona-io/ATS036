STARFLEET = 'starfleet-036-040-02-02'
ENFORCE = 'pod-security.kubernetes.io/enforce'


def privileged_containers(spec):
    containers = spec.get('containers', []) + spec.get('initContainers', [])
    return [container['name'] for container in containers if (container.get('securityContext') or {}).get('privileged') is True]


if wants('namespace-enforced'):
    labels = get('namespace', STARFLEET, None)['metadata'].get('labels', {})
    assert labels.get(ENFORCE) in ('baseline', 'restricted'), 'Namespace ' + STARFLEET + ' needs the label ' + ENFORCE + '=baseline'
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'privileged-check', 'namespace': STARFLEET}, 'spec': {'restartPolicy': 'Never', 'containers': [{'name': 'main', 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600'], 'securityContext': {'privileged': True}}]}}
    result = subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod), capture_output=True, text=True, timeout=20)
    output = (result.stdout + result.stderr).lower()
    assert result.returncode != 0, 'A privileged Pod is still accepted in ' + STARFLEET
    assert 'violates podsecurity' in output, 'A privileged Pod was rejected, but not by Pod Security Admission'

if wants('workload-replaced'):
    deployment = get('deployment', 'telemetry-agent', STARFLEET)
    template = deployment['spec']['template']['spec']
    assert [container['name'] for container in template['containers']] == ['agent'], 'Keep the single container agent in telemetry-agent'
    assert template['containers'][0]['image'] == 'docker.io/library/busybox:1.37.0', 'Keep the agent image docker.io/library/busybox:1.37.0'
    assert not privileged_containers(template), 'The telemetry-agent Pod template still asks for a privileged container'
    pods = json.loads(kubectl('-n', STARFLEET, 'get', 'pods', '-o', 'json'))['items']
    agents = [pod for pod in pods if pod['metadata'].get('labels', {}).get('app') == 'telemetry-agent']
    assert agents, 'No telemetry-agent Pod runs'
    for pod in pods:
        name = pod['metadata']['name']
        assert not privileged_containers(pod['spec']), 'Pod ' + name + ' still runs a privileged container'
        assert not pod['spec'].get('hostPID'), 'Pod ' + name + ' still shares the host process namespace'
