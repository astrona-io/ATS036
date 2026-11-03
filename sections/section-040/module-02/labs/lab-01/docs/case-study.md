---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Create Pod `capability-free` running BusyBox as user and group 2000, with `runAsNonRoot: true` and RuntimeDefault seccomp. Its container `worker` must disable privilege escalation and drop all capabilities. The process must hold no capability, `no_new_privs` must be set, and the Pod must stay running.
