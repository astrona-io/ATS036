---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The isolated environment runs the `probe` Deployment with two replicas and a Service in `starfleet-036-030-03-01`, and the idle Pods `shuttle` and `drifter`. One more Pod, in the `outpost-036-030-03-01` namespace, sends a request to the `probe` Service every five seconds. The required result has not been configured.

Identify the Pod that sends unexpected requests to the probe Service and record its address.
