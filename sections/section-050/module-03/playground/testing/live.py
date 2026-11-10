import os
records=[json.loads(line) for line in command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-playground-050-03")+"-control-plane"),'cat','/var/log/training-audit/audit.jsonl']).stdout.splitlines() if line.strip()]
report=get('configmap','audit-retention')['data']
manifest=json.loads(command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-playground-050-03")+"-control-plane"),'cat','/etc/kubernetes/manifests/kube-apiserver.yaml']).stdout)
flags=dict(arg[2:].split('=',1) for arg in manifest['spec']['containers'][0]['command'] if arg.startswith('--audit-') and '=' in arg)
assert flags['audit-policy-file']==report['policyFile'] and flags['audit-log-path']==report['logPath'], 'Report the live paths'
assert flags['audit-log-maxage']==report['maxAge'] and flags['audit-log-maxbackup']==report['maxBackup'] and flags['audit-log-maxsize']==report['maxSize'], 'Report the live rotation settings'
mode=command([(os.environ.get("ASTRONA_CONTAINER_ENGINE") or "podman"),'exec',(os.environ.get("ASTRONA_KIND_CLUSTER", "astro-ats-036-playground-050-03")+"-control-plane"),'stat','-c','%a',report['logPath']]).stdout.strip()
assert mode==report['logMode'], 'Report the live file mode'
assert records, 'The audit log must hold records'
assert kubectl('get','--raw=/readyz')=='ok', 'Preserve API availability'
