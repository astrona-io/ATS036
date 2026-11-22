---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Link An Exec Audit Record To Its Node And Container

The learner starts from the audit record of one `kubectl exec` request and links it to runtime evidence: the Pod that received the request, the container named in the request, the node that runs the Pod and the container ID from the Pod status. The result is ConfigMap `exec-correlation` in `starfleet-036-010-03-02`.

The lab runs in its own pinned kind cluster with one control-plane node and one worker. Setup turns on API audit logging (`bootstrap/enable-audit.py`), spreads the two `probe` replicas across both nodes, gives each Pod a `log-agent` container in front of the `probe` container, and runs one `kubectl exec` into the `probe` container of the replica on the control-plane node. The audit ID, Pod name, node and container ID are created at run time, so `solution/apply.sh` reads them live and the graders compare the ConfigMap with the live audit log and Pod status.

Run `testing/smoke.sh` with the lab's private kubeconfig to check that the starting state fails and the reference result passes. Static validation is not live evidence. Runtime verification remains pending until a real run is recorded.
