---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

A security review found four problems in the namespace `starfleet`. Pod `crash-report` keeps restarting. Pod `login-service` wrote many failed logins. Pod `suspect-pod` runs with extra privileges. The ServiceAccount `reporter` can read Secrets that it does not need. The ServiceAccount `auditor` has a legitimate, read-only Pod permission.

Create ConfigMap `threat-register` with `crashExitCode` (the exit code of the previous instance of `crash-report`), `failedLogins` (the number of `login failed` lines in `login-service`), `privilegedPod` (the Pod name) and `secretReader` (the short name of the ServiceAccount that can read Secrets). Then delete RoleBinding `reporter-secrets`. Keep RoleBinding `auditor-pods`. Do not delete or change any Pod, because the Pods are the evidence.
