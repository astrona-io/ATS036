---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Summary

An investigation names the phase of an attack that each observation belongs to: initial access, execution, persistence, privilege escalation, defense evasion, credential access, discovery, lateral movement or impact. The phases are not a strict sequence, and a failed attempt such as a denied Secret request still shows intent. `kubectl auth can-i --as` shows what an identity may do, which is what the attacker can learn during discovery.

An audit event names the authenticated identity, not a person. Kubernetes has users, groups, ServiceAccounts, nodes and anonymous requests, and impersonation adds a second identity to the record. The fields `user.groups`, `user.extra`, `sourceIPs` and `userAgent` support attribution, but a client can control the user agent and proxies can change the source address. A token projected into a Pod is bound to that Pod, and its UID identifies the Pod better than its name.

A timeline merges audit records, object metadata, container logs and sensor events, sorted by time in UTC after the clocks are checked. The audit policy decides which events exist, so a gap is not proof of a quiet period. Each line of the timeline is a fact that a record shows or a hypothesis that needs more evidence.

Containment preserves, isolates, revokes and then removes. Deleting a Pod that a ReplicaSet owns only creates a replacement from the same template, and it destroys process state and logs. Tokens projected into a Pod end with the Pod, but tokens created for a ServiceAccount and long-lived token Secrets continue until they expire or are deleted. Secrets that the identity could read need rotation. The key facts to remember are these:

- Name the attack phase of each observation.
- An identity in a record is a credential, not a person.
- Keep facts and hypotheses apart in the timeline.
- Preserve evidence first, and remove the cause as well as the Pod.

<!-- astrona:playground:destroy -->
