---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The isolated environment has the `probe` Deployment, the `shuttle` and `drifter` Pods, and the `threat-client` Pod that is denied when it reads the Secret `audit-token`. Three things are unexplained: the `cache-sync` Deployment in `starfleet`, which runs as the `build-helper` ServiceAccount; the RoleBinding that gives that ServiceAccount its permissions; and a Pod in `outpost` that sends a request to the `probe` Service every five seconds. The API server writes an audit log on the control plane node. The required result has not been configured.

Combine audit, ownership, binding and network evidence into one incident report and contain the workload and its authority.
