AUDIT_LOG = '/var/log/training-audit/audit.jsonl'
STARFLEET = 'starfleet-036-050-01-02'
DRIFTER = 'system:serviceaccount:outpost-036-050-01-02:drifter'


def denied_reads():
    """ResponseComplete records of a denied get of navigation-key sent as the drifter ServiceAccount."""
    lines = node_exec(NODE, 'grep', '-F', 'navigation-key', AUDIT_LOG, success=False).stdout.splitlines()
    records = [json.loads(line) for line in lines if line.strip()]
    return [
        record for record in records
        if record.get('stage') == 'ResponseComplete'
        and record.get('verb') == 'get'
        and record.get('objectRef', {}).get('resource') == 'secrets'
        and record.get('objectRef', {}).get('namespace') == STARFLEET
        and record.get('objectRef', {}).get('name') == 'navigation-key'
        and record.get('impersonatedUser', {}).get('username') == DRIFTER
        and record.get('responseStatus', {}).get('code') == 403
    ]


if wants('denied-request-sent'):
    records = denied_reads()
    assert records, 'No audit record shows a denied get of Secret navigation-key sent as ' + DRIFTER
    assert all(record.get('level') == 'Metadata' and 'requestObject' not in record and 'responseObject' not in record for record in records), 'Keep Secret records at Metadata level without bodies'
    assert kubectl('get', '--raw=/readyz') == 'ok', 'Preserve API availability'

if wants('audit-report'):
    report = get('configmap', 'denied-read-report').get('data', {})
    matching = [record for record in denied_reads() if record.get('auditID') == report.get('auditID', '').strip()]
    assert matching, 'The auditID in denied-read-report does not belong to a denied read of navigation-key as ' + DRIFTER
    assert report.get('user', '').strip() == matching[0].get('user', {}).get('username'), 'The user in denied-read-report must be the user.username of that record'
