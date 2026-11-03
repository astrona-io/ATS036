---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

Pod `suspect-pod` runs a container with extra privileges and mounts a directory of the node. Pod `login-service` and the healthy probe application are separate from that evidence Pod.

Leave Pod `suspect-pod` running. Read its specification. Create ConfigMap `pod-risk-report` with `pod: suspect-pod`, `privileged` matching the container `securityContext`, and `hostPath` matching the node directory that the Pod mounts. Do not delete or change the evidence Pod.
