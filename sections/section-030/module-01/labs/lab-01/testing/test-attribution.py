#!/usr/bin/env python3
"""Reject reports that cannot be tied to the live workload and audit event."""
import copy
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

NAMESPACE = 'starfleet-036-030-01-01'
ACTOR = f'system:serviceaccount:{NAMESPACE}:threat-reader'
POD = {'metadata': {'name': 'threat-client', 'uid': 'live-uid'},
       'spec': {'serviceAccountName': 'threat-reader'}, 'status': {'podIP': '10.244.1.3'}}
RECORD = {
    'auditID': 'observed-request', 'stage': 'ResponseComplete',
    'user': {'username': ACTOR, 'extra': {
        'authentication.kubernetes.io/pod-uid': ['live-uid'],
        'authentication.kubernetes.io/pod-name': ['threat-client']}},
    'sourceIPs': ['10.244.1.3'], 'responseStatus': {'code': 403},
    'objectRef': {'resource': 'secrets', 'namespace': NAMESPACE},
    'requestURI': f'/api/v1/namespaces/{NAMESPACE}/secrets/audit-token',
}
REPORT = {'auditID': RECORD['auditID'], 'stage': RECORD['stage'], 'actor': ACTOR,
          'resource': 'secrets', 'namespace': NAMESPACE, 'code': '403',
          'requestURI': RECORD['requestURI'], 'podName': 'threat-client',
          'podUID': 'live-uid', 'podIP': '10.244.1.3', 'sourceIP': '10.244.1.3'}
CODE = compile(Path(__file__).with_name('live.py').read_text(), 'live.py', 'exec')


def grade(report, record):
    def get(kind, name):
        return POD if kind == 'pod' else {'data': report}
    exec(CODE, {'json': json, 'get': get, 'wants': lambda _: True,
                'command': lambda _: SimpleNamespace(stdout=json.dumps(record))})


class AttributionTests(unittest.TestCase):
    def test_observed_identity_passes(self):
        grade(REPORT, RECORD)

    def test_nat_address_preserves_bound_identity(self):
        grade(dict(REPORT, sourceIP='172.18.0.3'),
              dict(RECORD, sourceIPs=['172.18.0.3']))

    def test_stale_and_unrelated_reports_fail(self):
        for key, value in [('auditID', 'another-request'), ('podUID', 'old-uid'),
                           ('sourceIP', '10.244.1.9'), ('podIP', '10.244.1.9'), ('podName', 'another-pod'),
                           ('actor', 'system:serviceaccount:other:threat-reader')]:
            with self.subTest(key=key):
                with self.assertRaises(AssertionError):
                    grade(dict(REPORT, **{key: value}), RECORD)

    def test_audit_evidence_must_match_live_pod(self):
        for field, values in [('authentication.kubernetes.io/pod-uid', ['old-uid']),
                              ('authentication.kubernetes.io/pod-name', ['another-pod'])]:
            record = copy.deepcopy(RECORD)
            record['user']['extra'][field] = values
            with self.subTest(field=field), self.assertRaises(AssertionError):
                grade(REPORT, record)

    def test_wrong_source_and_captured_payload_fail(self):
        for change in ({'sourceIPs': ['10.244.1.9']}, {'responseObject': {'data': 'secret'}}):
            with self.subTest(change=change), self.assertRaises(AssertionError):
                grade(REPORT, dict(RECORD, **change))


if __name__ == '__main__':
    unittest.main()
