import os
reader='--as=system:serviceaccount:starfleet:reporter'
auditor='--as=system:serviceaccount:starfleet:auditor'
assert command(['kubectl','auth','can-i','get','secrets','-n','starfleet',reader]).stdout.strip()=='yes', 'Preserve the access under review'
denied=command(['kubectl','auth','can-i','get','secrets','-n','starfleet',auditor],success=False)
assert denied.stdout.strip()=='no', 'The auditor must stay without Secret access'
finding=get('configmap','access-finding')['data']
binding=get('rolebinding',finding['binding'])
assert binding['subjects'][0]['name']=='reporter', 'Record the binding that grants the access'
assert 'system:serviceaccount:starfleet:'+binding['subjects'][0]['name']==finding['subject'], 'Record the actual subject'
