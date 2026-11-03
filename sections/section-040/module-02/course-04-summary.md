---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Summary

A container process holds Linux capabilities, which are named units of the power of root. The runtime gives every container a default list that includes rights to change file ownership, skip file permission checks, change user identity and open raw network sockets. The `capabilities.drop` setting with the value `ALL` removes the list, and the lines `CapBnd` and `CapEff` in `/proc/1/status` show the result as zeros. Most applications need no capability, and the common exception is `NET_BIND_SERVICE` for ports below 1024.

The identity of the process matters as well. The fields `runAsUser` and `runAsGroup` set a numeric user and group, and `runAsNonRoot: true` makes the kubelet refuse to start a container whose user is root or cannot be shown to be non-root. The refusal appears as the status `CreateContainerConfigError` before any process starts.

The setting `allowPrivilegeEscalation: false` sets the `no_new_privs` flag, so a set-user-ID binary cannot raise rights. A `seccompProfile` of type `RuntimeDefault` adds a filter that blocks system calls a container rarely needs. Together these settings give a process with a normal identity, an empty capability set, no way to escalate and a smaller kernel surface.

A privileged container reverses all of this. It receives all capabilities and the devices of the node, and it ignores the other settings. Added capabilities such as `SYS_ADMIN`, host namespaces and `hostPath` volumes weaken a container in a similar way. Listing the stored Pod fields finds these Pods, and Pod Security Admission in `enforce` mode with the `baseline` standard rejects new ones. The proof of a hardened container is on the running process: a non-zero user ID, a zero `CapEff` and `NoNewPrivs` set to `1`.

Key facts:

- `capabilities.drop: ["ALL"]` is set in the container `securityContext`, not in the Pod.
- `runAsNonRoot` is a check by the kubelet and needs a numeric user.
- `allowPrivilegeEscalation: false` sets `no_new_privs`.
- `privileged: true` overrides the capability, escalation and seccomp settings.
- Pod Security Admission checks new Pods only.

<!-- astrona:playground:destroy -->
