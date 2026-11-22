def intruder_ip():
    return kubectl('-n', 'outpost-036-030-03-01', 'get', 'pod', 'intruder', '-o', 'jsonpath={.status.podIP}')


if wants('source-pod'):
    report = get('configmap', 'lateral-finding')['data']
    assert report['sourceIP'] == intruder_ip(), 'The recorded address must belong to the intruder Pod'

if wants('probe-access'):
    report = get('configmap', 'lateral-finding')['data']
    logs = kubectl('-n', 'starfleet-036-030-03-01', 'logs', '-l', 'app=probe', '--tail=-1')
    assert any(line.split(' ')[0] == report['sourceIP'] for line in logs.splitlines()), 'The probe logs must show requests from the recorded address'
