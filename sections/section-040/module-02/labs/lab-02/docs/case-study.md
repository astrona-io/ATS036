---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The namespace `starfleet-036-040-02-02` runs the `probe` and `telemetry-agent` Deployments and the Pods `shuttle`, `node-inspector` and `beacon`. A review found that one container in this namespace runs privileged and one Pod shares the process namespace of the node. Not every extra right is a finding: the `baseline` Pod Security Standard allows a short list of added capabilities.

The namespace has no Pod Security Admission label, so the API server accepts any Pod in it. The team wants the API server to reject privileged Pods from now on, and the affected workload must run again without privileged mode.
