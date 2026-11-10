if wants('stop-persistence'):
    pods=json.loads(kubectl('-n','starfleet-036-030-02-01','get','pods','-l','app=cache-sync','-o','json'))['items']
    assert not pods, 'The cache-sync Pods must be gone'

if wants('revoke-authority'):
    assert not kubectl('-n', 'starfleet-036-030-02-01', 'get', 'rolebinding', 'build-helper-edit', '--ignore-not-found', '-o', 'name'), 'The attacker binding must be removed'
