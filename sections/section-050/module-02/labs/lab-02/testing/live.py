import time

POLICY_FILE = '/etc/kubernetes/training-audit-policy.json'
AUDIT_LOG = '/var/log/training-audit/audit.jsonl'
STARFLEET = 'starfleet-036-050-02-02'


def staged_policy():
    result = node_exec(NODE, 'cat', POLICY_FILE, success=False)
    assert result.returncode == 0, 'Keep the audit policy file ' + POLICY_FILE + ' on the control plane node'
    try:
        return json.loads(result.stdout)
    except ValueError:
        raise AssertionError('Keep the audit policy file as valid JSON')


def resource_matches(entries, resource, subresource, name):
    """The resource matching of the API server's audit policy checker."""
    combined = resource + '/' + subresource if subresource else resource
    for entry in entries:
        if entry.get('group', '') != '':
            continue
        names = entry.get('resources') or []
        if not names:
            return True
        for listed in names:
            if entry.get('resourceNames') and name not in entry['resourceNames']:
                continue
            if listed in (combined, '*'):
                return True
            if subresource and listed.startswith('*/') and listed[2:] == subresource:
                return True
            if listed.endswith('/*') and listed[:-2] == resource:
                return True
    return False


def policy_level(policy, identity, verb, subresource):
    """The level of the first rule that matches a request for a subresource of Pod shuttle."""
    for rule in policy.get('rules') or []:
        if rule.get('users') and identity['username'] not in rule['users']:
            continue
        if rule.get('userGroups') and not set(identity.get('groups') or []) & set(rule['userGroups']):
            continue
        if rule.get('verbs') and verb not in rule['verbs']:
            continue
        if rule.get('nonResourceURLs'):
            continue
        if rule.get('namespaces') and STARFLEET not in rule['namespaces']:
            continue
        if not rule.get('resources') or resource_matches(rule['resources'], 'pods', subresource, 'shuttle'):
            return rule.get('level')
    return 'None'


def pod_access_records(marker, subresource):
    lines = node_exec(NODE, 'grep', '-F', marker, AUDIT_LOG, success=False).stdout.splitlines()
    records = [json.loads(line) for line in lines if line.strip()]
    return [
        record for record in records
        if record.get('objectRef', {}).get('resource') == 'pods'
        and record['objectRef'].get('subresource') == subresource
        and record['objectRef'].get('namespace') == STARFLEET
    ]


def without_bodies(records):
    return all(record.get('level') == 'Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in records)


if wants('policy-order'):
    policy = staged_policy()
    identity = json.loads(kubectl('auth', 'whoami', '-o', 'json'))['status']['userInfo']
    for subresource in ('exec', 'portforward'):
        # kubectl sends exec and portforward as a POST (create) or as a WebSocket GET (get).
        for verb in ('create', 'get'):
            level = policy_level(policy, identity, verb, subresource)
            assert level == 'Metadata', f'The first rule that matches a {verb} of pods/{subresource} sets level {level}, not Metadata'
    for subresource in ('log', 'status'):
        level = policy_level(policy, identity, 'get', subresource)
        assert level == 'None', f'Keep dropping pods/{subresource}: the first matching rule sets level {level}'

if wants('exec-recorded'):
    marker = 'audit-check-' + os.urandom(4).hex()
    command(['kubectl', '-n', STARFLEET, 'exec', 'shuttle', '--', 'echo', marker])
    records = []
    for attempt in range(8):
        records = [record for record in pod_access_records(marker, 'exec') if record['objectRef'].get('name') == 'shuttle']
        if records:
            break
        time.sleep(1)
    assert records, 'A new exec request in Pod shuttle left no audit record: the running API server does not record pods/exec'
    assert without_bodies(records), 'Record exec requests at Metadata level without bodies'

if wants('portforward-recorded'):
    records = pod_access_records('portforward', 'portforward')
    assert records, 'No audit record of a pods/portforward request in ' + STARFLEET
    assert without_bodies(records), 'Record port-forward requests at Metadata level without bodies'
