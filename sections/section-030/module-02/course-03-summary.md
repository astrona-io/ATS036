---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Summary

Persistence means that attacker code or access survives the removal of the first Pod. In Kubernetes the persistent objects are controller templates (Deployments, StatefulSets, DaemonSets), CronJobs, RoleBindings, ClusterRoleBindings, long-lived token Secrets and, on a node, static Pod manifests. Following `ownerReferences` from a Pod through its ReplicaSet to the Deployment finds the object that recreates it, and the Deployment template shows the image, command, environment and ServiceAccount that every new Pod receives.

Authority comes from RBAC bindings and from Pod settings. A RoleBinding that references a ClusterRole grants its rules only inside the namespace of the binding. `kubectl auth can-i --list --as` shows what an identity may do, which is more reliable than the name of a role. The verbs `escalate`, `bind` and `impersonate`, the right to create Pods or tokens, and settings such as `privileged`, `hostPID` and `hostPath` raise authority.

Containment treats the workload and the authority as two separate problems. Preserve the Deployment, the binding and the logs first. Then scale the Deployment to zero, remove the binding that gave the authority and leave the bindings of normal operation. Rotate the Secrets that the identity could read, because a read that happened cannot be undone. The key facts to remember are these:

- Delete the owner, or scale it to zero, not only the Pod.
- A binding is evidence and must be saved before it is removed.
- Test permissions with `kubectl auth can-i --as`.

<!-- astrona:playground:destroy -->
