evidence=get('pod','suspect-pod')
container=evidence['spec']['containers'][0]
assert container['securityContext']['privileged'] is True, 'Preserve the evidence Pod'
assert evidence['spec']['volumes'][0]['hostPath']['path']=='/etc', 'Preserve the evidence Pod'
report=get('configmap','pod-risk-report')['data']
assert report['privileged']==str(container['securityContext']['privileged']).lower(), 'Record the actual privileged setting'
assert report['hostPath']==evidence['spec']['volumes'][0]['hostPath']['path'], 'Record the actual host path'
