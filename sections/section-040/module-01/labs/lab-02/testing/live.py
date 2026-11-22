POLICY = 'require-read-only-root-036-040-01-02'
BINDING = 'require-read-only-root-starfleet-036-040-01-02'
MESSAGE = 'Every container must set readOnlyRootFilesystem to true.'
STARFLEET = 'starfleet-036-040-01-02'
OUTPOST = 'outpost-036-040-01-02'


def check_container(name, read_only):
    container = {'name': name, 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sleep', '3600']}
    if read_only:
        container['securityContext'] = {'readOnlyRootFilesystem': True}
    return container


def dry_run_pod(namespace, name, containers):
    """Send a Pod to the API server with a server-side dry run; nothing is stored."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': namespace}, 'spec': {'restartPolicy': 'Never', 'containers': containers}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(pod), capture_output=True, text=True, timeout=20)


def bound_policy():
    policy = get('validatingadmissionpolicy', POLICY, None)
    binding = get('validatingadmissionpolicybinding', BINDING, None)
    assert policy['spec'].get('validations'), 'The policy needs a validation expression'
    assert binding['spec'].get('policyName') == POLICY, 'The binding must name policy ' + POLICY
    assert 'Deny' in binding['spec'].get('validationActions', []), 'The binding must use validationActions Deny'
    return policy, binding


def assert_denied(result, what):
    output = (result.stdout + result.stderr).lower()
    assert result.returncode != 0, what + ' was accepted; the policy must reject it (the binding can take a few seconds to become active)'
    assert POLICY in output, what + ' was rejected, but not by policy ' + POLICY
    assert MESSAGE.lower() in output, what + ' was rejected without the message: ' + MESSAGE


def assert_accepted(result, what):
    assert result.returncode == 0, what + ' was rejected: ' + result.stderr.strip()[:300]


if wants('policy-denies'):
    policy, binding = bound_policy()
    assert policy['spec'].get('failurePolicy', 'Fail') == 'Fail', 'Keep failurePolicy Fail'
    assert_denied(dry_run_pod(STARFLEET, 'writable-check', [check_container('main', False)]), 'A writable Pod in ' + STARFLEET)
    assert_denied(dry_run_pod(STARFLEET, 'sidecar-check', [check_container('main', True), check_container('sidecar', False)]), 'A Pod with a writable second container in ' + STARFLEET)

if wants('compliant-allowed'):
    bound_policy()
    assert_accepted(dry_run_pod(STARFLEET, 'compliant-check', [check_container('main', True), check_container('sidecar', True)]), 'A Pod whose containers all set readOnlyRootFilesystem in ' + STARFLEET)

if wants('scope-limited'):
    policy, binding = bound_policy()
    selector = binding['spec'].get('matchResources', {}).get('namespaceSelector') or {}
    assert selector.get('matchLabels') or selector.get('matchExpressions'), 'The binding must select namespaces with a namespaceSelector'
    labels = {name: get('namespace', name, None)['metadata'].get('labels', {}) for name in (STARFLEET, OUTPOST)}
    assert labels[STARFLEET].get('immutability') == 'enforced', 'Namespace ' + STARFLEET + ' needs the label immutability=enforced'
    assert 'immutability' not in labels[OUTPOST], 'Namespace ' + OUTPOST + ' must not carry the immutability label'
    assert_accepted(dry_run_pod(OUTPOST, 'writable-check', [check_container('main', False)]), 'A writable Pod in ' + OUTPOST)
