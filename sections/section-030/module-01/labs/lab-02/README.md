---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Isolate A Compromised Pod And Revoke Its Token

Quarantine a compromised bare Pod without deleting it, cut its network traffic with a NetworkPolicy, delete the long-lived token Secret of its ServiceAccount and remove the RoleBinding that lets it read Secrets, while a legitimate ServiceAccount keeps its access.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
