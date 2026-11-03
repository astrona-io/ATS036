---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Summary

Lateral movement is the use of one compromised workload to reach others. The evidence is on the receiving side: an application access log lists the client address of each request. Mapping that address to a Pod with `kubectl get pods -A -o wide` identifies the source, and the readiness probe requests of the kubelet come from the node network and match no Pod.

The mapping is only as strong as its timing, because Pod addresses are reused and proxies can replace the source address. A missing log line proves nothing, since logs rotate, applications log selectively and traffic can use other ports. Write the log lines as facts and the conclusion about the attacker as a hypothesis.

Impact leaves different marks: Pods without resource limits that can take a node, restarts, `OOMKilled` containers and events that record kills and evictions. Combine small signals and decide which fit. ResourceQuota and LimitRange reduce the harm that one workload can do, and live use needs a metrics source such as the Metrics Server. The key facts to remember are these:

- The access log of the target shows who connected.
- A client address is a lead until the timing is checked.
- Save events early, because they expire.

<!-- astrona:playground:destroy -->
