---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

Pod `login-service` in `starfleet-036-020-02-02` writes one line to its log for every login attempt, in the form `login failed user=<name> src=<address>` or `login ok user=<name> src=<address>`. It also writes start, health and ready lines. The healthy probe application and the `shuttle` and `drifter` Pods are not part of the evidence.

Leave Pod `login-service` running and do not restart it, because a restart starts a new log. Read its log. Create ConfigMap `login-findings` with `failedCount` set to the number of lines that contain `login failed`, `targetUser` and `sourceAddress` set to the user and address with the most failures, and `successUser` set to the user that logged in from that address after those failures.
