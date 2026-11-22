---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find A Pod's Log Files On Its Node

The learner finds the log files of Pod `crash-report` on the node that runs it: the Pod log directory `/var/log/pods/<namespace>_<pod>_<uid>`, one file per container instance in the `report` container directory, and a random token that only the first, crashed instance wrote. The result is ConfigMap `node-log-evidence` in `starfleet-036-020-01-02`.

The lab runs in its own pinned kind cluster with one control-plane node and one worker. Setup starts Pod `crash-report` in `starfleet-036-020-01-02`, which exits once and then keeps running, and a second Pod `crash-report` in `outpost-036-020-01-02` whose log directory sits next to it on the node. The node, the Pod UID and the token are created at run time, so `solution/apply.sh` reads them live and the graders read the node with `node_exec()` on the node that runs the Pod.

Run `testing/smoke.sh` with the lab's private kubeconfig to check that the starting state fails and the reference result passes. Static validation is not live evidence. Runtime verification remains pending until a real run is recorded.
