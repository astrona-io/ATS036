def node_report_template():
    """The Pod template of the node-report CronJob, kept as evidence."""
    cron_job = get('cronjob', 'node-report')
    return cron_job['spec']['jobTemplate']['spec']['template']['spec']


def owned_by_node_report(item):
    return any(reference.get('kind') == 'CronJob' and reference.get('name') == 'node-report'
               for reference in item['metadata'].get('ownerReferences', []))


def job_finished(job):
    return any(condition.get('type') in ('Complete', 'Failed') and condition.get('status') == 'True'
               for condition in job.get('status', {}).get('conditions', []))


if wants('cronjob-finding'):
    report = get('configmap', 'persistence-finding')['data']
    template = node_report_template()
    assert report.get('serviceAccount') == template.get('serviceAccountName'), 'Record the ServiceAccount of the node-report Pod template'
    assert template.get('hostPID') is True, 'Keep the node-report template unchanged as evidence'

if wants('cronjob-suspended'):
    template = node_report_template()
    assert template.get('serviceAccountName') == 'build-helper' and template.get('hostPID') is True, 'Suspend node-report without changing its template'
    jobs = json.loads(kubectl('-n', NAMESPACE, 'get', 'jobs', '-o', 'json'))['items']
    running = [job['metadata']['name'] for job in jobs if owned_by_node_report(job) and not job_finished(job)]
    assert not running, 'Delete the Jobs that node-report started: ' + ', '.join(running)
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=node-report', '-o', 'json'))['items']
    alive = [pod['metadata']['name'] for pod in pods if pod['status'].get('phase') in ('Pending', 'Running')]
    assert not alive, 'Wait until the node-report Pods are gone: ' + ', '.join(alive)
