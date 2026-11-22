def evidence_pod():
    evidence = get('pod', 'crash-report')
    assert evidence['spec']['containers'][0]['command'] == ['sh', '-c', 'printf "application-started\\n"; if [ ! -f /state/crashed ]; then touch /state/crashed; sleep 2; exit 12; fi; sleep 86400'], 'Preserve the evidence process'
    return evidence


if wants('previous-exit-code'):
    status = next(status for status in evidence_pod()['status']['containerStatuses'] if status['name'] == 'report')
    assert status['restartCount'] >= 1, 'Inspect a real previous container instance'
    assert str(status['lastState']['terminated']['exitCode']) == get('configmap', 'crash-diagnosis')['data']['exitCode'], 'Record the actual previous exit code'

if wants('previous-log-evidence'):
    evidence_pod()
