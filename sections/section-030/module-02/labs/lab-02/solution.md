---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Stop A Persistent CronJob Without Deleting It Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own kind cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A Pod that comes back every minute is not the real problem. The object that creates it is, and so is the authority that object hands to each new Pod. This task finds a CronJob, records what makes it dangerous and stops it in a way that keeps it as evidence.

## Find the object behind the Pod

Start with a list of the scheduling objects and what they have created:

```sh
kubectl -n starfleet-036-030-02-02 get cronjobs,jobs,pods
```

<!-- CAPTURE: lab2-objects-before -->

A CronJob is an object that the CronJob controller in kube-controller-manager reads on a schedule. At each scheduled time, the controller creates a Job from the CronJob's `jobTemplate`. A Job is an object that runs Pods until a set number of them finish, and the Job controller creates those Pods. So the `node-report` Pod belongs to a Job, and the Job belongs to the CronJob `node-report`. The `SUSPEND` column shows `False` for both CronJobs: the API server sets `suspend: false` by default when the field is left out.

You can confirm the chain from the Job side. Every Job that the CronJob controller creates carries an `ownerReferences` entry that names the CronJob:

```sh
kubectl -n starfleet-036-030-02-02 get jobs -o custom-columns=NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name
```

<!-- CAPTURE: lab2-job-owners -->

## Read the Pod template

The Pod template inside the CronJob decides what every future Pod looks like. Read the three fields that matter for this incident: whether the CronJob is suspended, which ServiceAccount its Pods run as, and whether they share the process namespace of the node:

```sh
kubectl -n starfleet-036-030-02-02 get cronjob node-report -o jsonpath='{.spec.suspend}{" "}{.spec.jobTemplate.spec.template.spec.serviceAccountName}{" "}{.spec.jobTemplate.spec.template.spec.hostPID}{"\n"}'
```

<!-- CAPTURE: lab2-template-before -->

`hostPID: true` tells the kubelet to start the container in the PID (process ID) namespace of the node instead of a namespace of its own. The container then sees every process on the node, including the kubelet and the container runtime, and it can read their command lines through `/proc`. A container that runs as root keeps the `CAP_KILL` capability by default, so it can also send signals to those processes and stop them. You can see the effect in the running Pod:

```sh
report_pod="$(kubectl -n starfleet-036-030-02-02 get pods -l app=node-report -o jsonpath='{.items[0].metadata.name}')"
kubectl -n starfleet-036-030-02-02 exec "$report_pod" -- ps -o pid,user,comm
```

<!-- CAPTURE: lab2-hostpid-ps -->

The list holds node processes, not only the `sh` and `sleep` of the container. A normal container would show only its own processes. Save the CronJob to a file before you change it, so the record keeps the template as it was:

```sh
kubectl -n starfleet-036-030-02-02 get cronjob node-report -o yaml > node-report-cronjob.yaml
```

Now record the finding. Save this as `configmap-persistence-finding.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: persistence-finding
  namespace: starfleet-036-030-02-02
data:
  cronJob: node-report
  serviceAccount: build-helper
  hostSetting: hostPID
```

Apply it:

```sh
kubectl apply -f configmap-persistence-finding.yaml
```

## Suspend the CronJob and remove its running Jobs

Deleting the CronJob would stop it, but it would also delete the template, which is the best evidence of what the attacker ran. Setting `spec.suspend` to `true` tells the CronJob controller to create no new Jobs, and it keeps the object as it is. Suspend it first, so no new Job starts while you clean up:

```sh
kubectl -n starfleet-036-030-02-02 patch cronjob node-report --type=merge -p '{"spec":{"suspend":true}}'
```

Suspending does not touch Jobs that already exist. The running Job keeps its Pod until the command in the Pod ends, and here that command sleeps for ten minutes. Delete the Jobs of `node-report`. The Job template gives them the label `app=node-report`, so a label selector finds them:

```sh
kubectl -n starfleet-036-030-02-02 delete jobs -l app=node-report
```

When kubectl deletes a Job, the garbage collector in kube-controller-manager deletes the Pods that the Job owns. The kubelet then stops each container, which takes up to the grace period of five seconds that the template sets. Wait until the Pods are gone, with a time limit:

```sh
kubectl -n starfleet-036-030-02-02 wait --for=delete pod -l app=node-report --timeout=90s
```

If kubectl reports that no matching resources were found, the Pods were already gone before the command ran. Then check the result:

```sh
kubectl -n starfleet-036-030-02-02 get cronjobs,jobs,pods
```

<!-- CAPTURE: lab2-objects-after -->

`node-report` shows `True` in the `SUSPEND` column and no `node-report` Job or Pod remains. `probe-check` still shows `False`, so the normal schedule keeps running. Run the same command again after the next full minute. The CronJob controller skips a suspended CronJob, so no new `node-report` Job appears.

You now have the CronJob preserved and suspended, and no code of it is left running. The open question is the authority of `build-helper`. A suspended CronJob starts no new Pods, but the ServiceAccount keeps every permission its RoleBindings give it, so an incident team checks those bindings next.

When you are done, remove the lab with `astrona destroy ats-036-lab-030-02-02`.

## Common pitfalls

> [!WARNING]
> - **Deleting the CronJob.** It stops the schedule, but the template, the best evidence, is gone. Suspend it instead.
> - **Suspending and stopping there.** `suspend: true` only stops new Jobs. A Job that is already running keeps its Pod until you delete the Job.
> - **Deleting only the Pod.** The evidence in the Pod is lost, and a Job that allows retries gets a replacement Pod from the Job controller. Delete the Job, and the garbage collector removes its Pods.
> - **Suspending the wrong CronJob.** `probe-check` belongs to normal operation and must keep its schedule.
