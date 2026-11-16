#!/usr/bin/env python3
"""Check both exec transports while preserving audit identity checks."""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

CODE = compile(Path(__file__).with_name('live.py').read_text(), 'live.py', 'exec')
REPORT = {'deniedAuditID': 'denied', 'deniedActor': 'reader',
          'execAuditID': 'exec', 'execActor': 'operator',
          'execStage': 'ResponseStarted', 'podName': 'probe-evidence'}


def grade(verb, actor='operator', target='probe-evidence'):
    records = [
        {'auditID': 'denied', 'stage': 'ResponseComplete',
         'user': {'username': 'reader'}, 'objectRef': {'resource': 'secrets'},
         'responseStatus': {'code': 403}},
        {'auditID': 'exec', 'stage': 'ResponseStarted', 'verb': verb,
         'user': {'username': actor},
         'objectRef': {'subresource': 'exec', 'name': target}},
    ]
    def get(kind, name):
        if kind == 'configmap':
            return {'data': REPORT}
        return {'metadata': {'labels': {'quarantine': 'true'}},
                'status': {'phase': 'Running'}}
    healthy = {'items': [{'metadata': {'name': f'probe-{i}'},
                          'status': {'phase': 'Running'}} for i in range(2)]}
    exec(CODE, {'json': json, 'get': get,
                'command': lambda _: SimpleNamespace(stdout=json.dumps(records[0])+'\n'+json.dumps(records[1])),
                'kubectl': lambda *args: json.dumps(healthy)})


class ExecEvidenceTests(unittest.TestCase):
    def test_post_and_websocket_requests_pass(self):
        for verb in ('create', 'get'):
            with self.subTest(verb=verb):
                grade(verb)

    def test_other_verbs_fail(self):
        with self.assertRaises(AssertionError):
            grade('delete')

    def test_actor_and_target_must_match_report(self):
        for kwargs in ({'actor': 'another-user'}, {'target': 'another-pod'}):
            with self.subTest(kwargs=kwargs), self.assertRaises(AssertionError):
                grade('get', **kwargs)


if __name__ == '__main__':
    unittest.main()
