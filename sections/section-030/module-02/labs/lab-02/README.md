---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Stop A Persistent CronJob Without Deleting It

Trace a recurring Pod to its CronJob, record it, suspend the CronJob without deleting it and remove the Jobs it already started, while a legitimate CronJob keeps running.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
