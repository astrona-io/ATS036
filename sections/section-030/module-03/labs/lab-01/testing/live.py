if wants('lateral-finding'):
    import os
    pod_ip=kubectl('-n','outpost-036-030-03-01','get','pod','intruder','-o','jsonpath={.status.podIP}')
    report=get('configmap','lateral-finding')['data']
    assert report['sourceIP']==pod_ip, 'The recorded address must belong to the intruder Pod'
    logs=kubectl('-n','starfleet-036-030-03-01','logs','-l','app=probe','--tail=-1')
    assert any(line.split(' ')[0]==pod_ip for line in logs.splitlines()), 'The probe logs must show requests from the recorded address'
