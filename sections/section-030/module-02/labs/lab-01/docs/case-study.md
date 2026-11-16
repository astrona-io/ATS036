---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The isolated environment runs the `cache-sync` Deployment with one replica, which uses the `build-helper` ServiceAccount, and two RoleBindings in the `starfleet-036-030-02-01` namespace. The `cache-sync` Deployment is not part of the application. The required result has not been configured.

Find the controller and binding behind an unexpected Pod, record them and contain both.
