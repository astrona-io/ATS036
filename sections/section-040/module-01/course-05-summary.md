---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Summary

A container image is a stack of read-only layers, and the container runtime adds one writable layer for each running container. A process can change files in that layer, install tools and run new programs. The changes disappear when the container is replaced, so the safe way to fix or update a workload is to replace the container from a reviewed image, pinned by digest, and never to patch it by hand.

A read-only root filesystem blocks the write step of an attack. The `readOnlyRootFilesystem` field works best together with a non-root user, `allowPrivilegeEscalation: false`, dropped capabilities and the `RuntimeDefault` seccomp profile. Applications that need to write get an `emptyDir` volume at the exact paths they use, and the volume is removed with the Pod.

A read-only root does not cover everything. Mounted volumes stay writable, code can run from memory, interpreters in the image can run attacker input, and secrets stay readable. Pod Security Admission enforces the `baseline` or `restricted` standard for a namespace, but `restricted` does not require a read-only root filesystem. A ValidatingAdmissionPolicy with a CEL expression closes that gap by rejecting Pods that omit the field.

Verification is part of immutability. Listing the stored `securityContext` of every Pod finds mutable workloads. The `imageID` of each container shows which digest runs. RBAC on the `pods/exec` subresource decides who can run commands in a container, and runtime detection tools watch for writes that the controls did not prevent.

Key facts:

- The root filesystem is mounted read-only with `readOnlyRootFilesystem: true`.
- `emptyDir` gives a non-root application a scratch path.
- `restricted` requires non-root, no privilege escalation, dropped capabilities and a seccomp profile.
- A ValidatingAdmissionPolicy needs a policy object and a binding with `validationActions`.
- `exec` is the verb `create` on `pods/exec`.

<!-- astrona:playground:destroy -->
