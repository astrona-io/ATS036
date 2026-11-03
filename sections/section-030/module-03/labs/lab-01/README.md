---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Trace A Connection To Its Source Pod

Identify the Pod that sends unexpected requests to the probe Service and record its address.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
