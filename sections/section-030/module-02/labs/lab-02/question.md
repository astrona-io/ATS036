---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Stop A Persistent CronJob Without Deleting It

Allow about 8 minutes for the tasks.

Every minute, a `node-report` Pod appears in `starfleet-036-030-02-02` and lists the processes of the node it runs on. No one on the team scheduled it. Stop it for good, but keep the CronJob as evidence.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-030-02-02` has the CronJobs `node-report` and `probe-check`, two ServiceAccounts and the RoleBinding `probe-reader-view`. A Job started by `node-report` is running. `probe-check` and the RoleBinding `probe-reader-view` belong to normal operation.

Use the private kubeconfig for `ats-036-lab-030-02-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-02)"` and check that the context is `kind-astro-ats-036-lab-030-02-02`.

## Tasks

1. Inspect the CronJob `node-report` and its Pod template. Create the ConfigMap `persistence-finding` in `starfleet-036-030-02-02` with the keys `cronJob`, `serviceAccount` and `hostSetting`. Record the CronJob name, the ServiceAccount of its Pods (`spec.jobTemplate.spec.template.spec.serviceAccountName`) and, as `hostSetting`, the name of the field `spec.jobTemplate.spec.template.spec.hostPID`, which is set to `true`. Save the CronJob manifest to a file on your host before you change it.
2. Suspend `node-report`. Do not delete it and do not change its Pod template. Then delete the Jobs it has already started and wait until their Pods are gone.
3. Check that `probe-check` still has `suspend: false` and that no `node-report` Pod starts again after the next full minute.

## Constraints

Work only in the namespace `starfleet-036-030-02-02`. Do not suspend or change the CronJob `probe-check`, and keep the RoleBinding `probe-reader-view`. Cluster startup adds time to the task estimate.

## How the answer is checked

Each check gives one point: the finding names the CronJob, its ServiceAccount and the `hostPID` setting of its Pod template; `node-report` is suspended and kept with its template unchanged, and none of its Jobs or Pods still run. Every check also requires that `probe-check` is not suspended and that `probe-reader-view` still exists. The grader reads live resources.
