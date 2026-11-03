pod_ip=kubectl('-n','outpost','get','pod','intruder','-o','jsonpath={.status.podIP}')
report=get('configmap','lateral-finding')['data']
assert report['sourceIP']==pod_ip, 'The recorded address must belong to the intruder Pod'
logs=kubectl('-n','starfleet','logs','-l','app=probe','--tail=-1')
assert any(line.split(' ')[0]==pod_ip for line in logs.splitlines()), 'The probe logs must show requests from the recorded address'
