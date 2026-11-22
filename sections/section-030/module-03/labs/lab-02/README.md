---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Find And Limit A Workload That Can Exhaust Its Node

Find the workload without resource limits and the Pod that was OOMKilled, then add limits to the workload and default limits to the namespace with a LimitRange.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence.
