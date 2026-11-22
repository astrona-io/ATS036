---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The namespace `starfleet-036-030-02-02` has two CronJobs. `node-report` runs every minute as the ServiceAccount `build-helper`, with `hostPID: true` in its Pod template, and one of its Jobs is running. `probe-check` runs every five minutes as the ServiceAccount `probe-reader` and belongs to normal operation.

Record the persistence and stop it while you keep the CronJob as evidence.
