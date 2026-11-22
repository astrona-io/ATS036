if wants('privileged-finding'):
    container = get('pod', 'suspect-pod')['spec']['containers'][0]
    assert container['securityContext']['privileged'] is True, 'Preserve the evidence Pod'
    report = get('configmap', 'pod-risk-report')['data']
    assert report['privileged'] == str(container['securityContext']['privileged']).lower(), 'Record the actual privileged setting'

if wants('host-path-finding'):
    evidence = get('pod', 'suspect-pod')
    assert evidence['spec']['volumes'][0]['hostPath']['path'] == '/etc', 'Preserve the evidence Pod'
    report = get('configmap', 'pod-risk-report')['data']
    assert report['hostPath'] == evidence['spec']['volumes'][0]['hostPath']['path'], 'Record the actual host path'
