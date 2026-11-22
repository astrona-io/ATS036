ALERT = get('configmap', 'shell-alert')['data']


def suspect():
    pod = get('pod', ALERT['pod'])
    assert pod['metadata']['uid'] == ALERT['uid'], 'Keep the suspect Pod: it was deleted or replaced'
    return pod


if wants('evidence-container'):
    pod = suspect()
    evidence = [item for item in pod['spec'].get('ephemeralContainers', []) if item['name'] == 'evidence']
    assert evidence, 'Add an ephemeral container named evidence to the suspect Pod'
    assert evidence[0].get('targetContainerName') == 'probe', 'Target the probe container so the evidence container sees its processes'
    statuses = [item for item in pod['status'].get('ephemeralContainerStatuses', []) if item['name'] == 'evidence']
    assert statuses and ('running' in statuses[0]['state'] or 'terminated' in statuses[0]['state']), 'The evidence container has not started yet'

if wants('pod-quarantined'):
    pod = suspect()
    labels = pod['metadata'].get('labels', {})
    assert 'app' not in labels and 'release' not in labels, 'Remove the app and release labels from the suspect Pod'
    assert labels.get('quarantine') == 'true', 'Label the suspect Pod quarantine=true'
    assert pod['status'].get('phase') == 'Running', 'The suspect Pod must keep running for analysis'

if wants('service-excludes'):
    pod = suspect()
    address = pod['status'].get('podIP')
    slices = json.loads(kubectl('get', 'endpointslices', '-n', NAMESPACE, '-l', 'kubernetes.io/service-name=probe', '-o', 'json'))['items']
    addresses = [ip for item in slices for endpoint in item.get('endpoints') or [] for ip in endpoint.get('addresses', [])]
    assert address and address not in addresses, 'The probe Service still sends traffic to the suspect Pod'
    owners = [owner['kind'] for owner in pod['metadata'].get('ownerReferences', [])]
    assert 'ReplicaSet' not in owners, 'The ReplicaSet still owns the suspect Pod'
    ready = [endpoint for item in slices for endpoint in item.get('endpoints') or [] if endpoint.get('conditions', {}).get('ready')]
    assert len(ready) >= 2, 'The probe Service needs two ready replacement endpoints'
