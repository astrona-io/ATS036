if wants('access-finding'):
    import os
    reader='--as=system:serviceaccount:starfleet-036-020-03-01:reporter'
    auditor='--as=system:serviceaccount:starfleet-036-020-03-01:auditor'
    assert command(['kubectl','auth','can-i','get','secrets','-n','starfleet-036-020-03-01',reader]).stdout.strip()=='yes', 'Preserve the access under review'
    denied=command(['kubectl','auth','can-i','get','secrets','-n','starfleet-036-020-03-01',auditor],success=False)
    assert denied.stdout.strip()=='no', 'The auditor must stay without Secret access'
    finding=get('configmap','access-finding')['data']
    binding=get('rolebinding',finding['binding'])
    assert binding['subjects'][0]['name']=='reporter', 'Record the binding that grants the access'
    assert 'system:serviceaccount:starfleet-036-020-03-01:'+binding['subjects'][0]['name']==finding['subject'], 'Record the actual subject'
