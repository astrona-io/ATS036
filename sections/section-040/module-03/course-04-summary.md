---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Summary

A volume is a separate filesystem from the root filesystem of the container, so a read-only root does not limit it. A `hostPath` volume mounts a directory of the node, and a writable mount lets a container change node files. Paths such as the container runtime socket or the kubelet directory give access to the whole node. The `baseline` and `restricted` Pod Security Standards forbid `hostPath` volumes. When one cannot be avoided, the Pod mounts the narrowest path and sets `readOnly: true` on the volume mount, which leaves the data readable and makes writes fail with `Read-only file system`.

A running container should never be the place where a change is made. A Deployment holds a Pod template, and a change to the template creates a new ReplicaSet, starts new Pods and removes the old ones. A file written by hand into an old Pod does not exist in the new Pods. The same rollout can add a read-only root filesystem with an `emptyDir` volume for temporary files. The `rollout history` and `rollout undo` commands show earlier revisions and start a rollout back to one of them. A rollback is also a replacement.

An image tag is a label that can move, and a digest identifies exact content. A reference with `@sha256:` makes the runtime pull and verify one specific image. The template shows the requested image and the `imageID` in the Pod status shows the image that runs. Comparing every `imageID` with an approved list, and comparing live objects with files in version control, finds workloads that changed outside review. A ValidatingAdmissionPolicy can reject tag-only images before they start.

Key facts:

- A `hostPath` volume is a directory of the node, not of the image.
- `readOnly: true` on a `volumeMount` makes writes through that mount fail.
- Only a change to the Pod template starts a rollout.
- A digest has the form `name@sha256:<hash>`.
- `imageID` in the Pod status is the proof of what runs.

<!-- astrona:playground:destroy -->
