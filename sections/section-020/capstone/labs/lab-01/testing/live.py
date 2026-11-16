import os
crash=get('pod','crash-report')
crash_status=next(status for status in crash['status']['containerStatuses'] if status['name']=='report')
assert crash_status['restartCount']>=1, 'Preserve the crashing evidence Pod'
register=get('configmap','threat-register')['data']
assert register['crashExitCode']==str(crash_status['lastState']['terminated']['exitCode']), 'Record the actual exit code'
login_log=command(['kubectl','-n','starfleet','logs','login-service']).stdout
assert register['failedLogins']==str(login_log.count('login failed')), 'Record the actual number of failed logins'
suspect=get('pod',register['privilegedPod'])
assert suspect['spec']['containers'][0]['securityContext']['privileged'] is True, 'Name the privileged Pod'
revoked=command(['kubectl','auth','can-i','get','secrets','-n','starfleet','--as=system:serviceaccount:starfleet:'+register['secretReader']],success=False)
assert revoked.stdout.strip()=='no', 'Remove the Secret access of the reader'
missing=command(['kubectl','-n','starfleet','get','rolebinding','reporter-secrets'],success=False)
assert missing.returncode!=0, 'Delete the RoleBinding that grants Secret access'
