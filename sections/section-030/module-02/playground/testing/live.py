import os
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=cache-sync','-o','json'))['items']
assert not pods, 'The cache-sync Pods must be gone'
assert command(['kubectl','-n','starfleet','get','rolebinding','build-helper-edit'],success=False).returncode!=0, 'The attacker binding must be removed'
