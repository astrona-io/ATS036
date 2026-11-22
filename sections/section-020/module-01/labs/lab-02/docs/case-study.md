---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

The cluster has one control-plane node and one worker. Pod `crash-report` in `starfleet-036-020-01-02` has one container, `report`. Its first instance printed `application-started` and a line `crash-token=<value>`, then exited with status 12. The kubelet started a second instance, which prints `application-started` and keeps running. A second Pod named `crash-report` runs in `outpost-036-020-01-02` and does not crash.

Find the log files of the `starfleet-036-020-01-02` Pod on its node and record them in ConfigMap `node-log-evidence`. Do not delete or restart the evidence Pod.
