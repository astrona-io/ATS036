LOG = kubectl('-n', NAMESPACE, 'logs', 'login-service').splitlines()
assert 'service ready' in LOG, 'Preserve the login-service Pod and its complete log'
FAILURES = [line.split() for line in LOG if 'login failed' in line]

if wants('failed-count'):
    report = get('configmap', 'login-findings')['data']
    assert report['failedCount'] == str(len(FAILURES)), 'Record the number of "login failed" lines in the live log'

if wants('attacker-detail'):
    report = get('configmap', 'login-findings')['data']
    pairs = [(fields[2], fields[3]) for fields in FAILURES]
    user, source = max(set(pairs), key=pairs.count)
    assert report['targetUser'] == user.removeprefix('user='), 'Record the user with the most failed logins'
    assert report['sourceAddress'] == source.removeprefix('src='), 'Record the source address of those failed logins'

if wants('success-after-failures'):
    report = get('configmap', 'login-findings')['data']
    source = 'src=' + report.get('sourceAddress', '')
    last_failure = max((index for index, line in enumerate(LOG) if 'login failed' in line and source in line.split()), default=None)
    assert last_failure is not None, 'Record the source address of the failed logins first'
    later = [line.split()[2].removeprefix('user=') for line in LOG[last_failure + 1:] if line.startswith('login ok') and source in line.split()]
    assert later and report['successUser'] == later[0], 'Record the user that logged in from that source address after its failures'
