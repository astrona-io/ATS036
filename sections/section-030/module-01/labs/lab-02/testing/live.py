def can_i(verb, resource, account):
    """Ask the API server whether a ServiceAccount of the lab namespace may do something."""
    result = command(['kubectl', '-n', NAMESPACE, 'auth', 'can-i', verb, resource,
                      '--as', f'system:serviceaccount:{NAMESPACE}:{account}'], success=False)
    answer = result.stdout.strip().split()
    assert answer and answer[0] in ('yes', 'no'), f'kubectl auth can-i gave no answer for {account}'
    return answer[0]


if wants('pod-quarantined'):
    ticket = get('configmap', 'incident-ticket')['data']
    pod = get('pod', 'threat-client')
    assert pod['metadata']['uid'] == ticket.get('podUID'), 'threat-client must be the original Pod named in incident-ticket, not a recreated one'
    assert pod['spec'].get('serviceAccountName') == 'threat-reader', 'Keep the original threat-client Pod'
    assert pod['metadata'].get('labels', {}).get('incident') == 'quarantine', 'Label threat-client with incident=quarantine'
    assert not pod['metadata'].get('deletionTimestamp') and pod['status'].get('phase') == 'Running', 'Keep threat-client running as evidence'
    labelled = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'incident=quarantine', '-o', 'json'))['items']
    assert [item['metadata']['name'] for item in labelled] == ['threat-client'], 'Only threat-client may carry incident=quarantine'

if wants('quarantine-policy'):
    spec = get('networkpolicy', 'quarantine')['spec']
    assert spec.get('podSelector') == {'matchLabels': {'incident': 'quarantine'}}, 'Select only Pods labelled incident=quarantine'
    assert sorted(spec.get('policyTypes', [])) == ['Egress', 'Ingress'], 'Set both Ingress and Egress in policyTypes'
    assert not spec.get('ingress') and not spec.get('egress'), 'Allow no ingress and no egress traffic'

if wants('token-revoked'):
    secrets = json.loads(kubectl('-n', NAMESPACE, 'get', 'secrets', '-o', 'json'))['items']
    left = [item['metadata']['name'] for item in secrets
            if item.get('type') == 'kubernetes.io/service-account-token'
            and (item['metadata'].get('annotations') or {}).get('kubernetes.io/service-account.name') == 'threat-reader']
    assert not left, 'Delete the token Secrets of threat-reader: ' + ', '.join(left)

if wants('access-revoked'):
    for verb in ('get', 'list'):
        assert can_i(verb, 'secrets', 'threat-reader') == 'no', f'threat-reader can still {verb} Secrets'
    assert can_i('get', 'secrets', 'probe-reader') == 'yes', 'probe-reader must keep its read access to Secrets'
