---
draft: true
---
# Deliver Audit Metadata Outside The Control Plane

Solve this question on: `terminal`

The independent VM runs a kind control-plane container and a separate TLS audit collector managed by systemd. The API server's webhook backend is mounted and enabled, but its credential is wrong and its policy records nothing.

Allow 10–15 minutes for task work. API server replacements add short waits.

## Tasks

1. Set the user token in `/etc/training/audit-webhook.json` to `training-audit-token`, preserving the HTTPS endpoint and certificate authority.
2. Set `/etc/training/audit-policy.json` to record Metadata for core Secrets and ConfigMaps in namespace `audited`, omit `RequestReceived`, and record None for everything else.
3. Run `sudo reload-training-audit`, then create fresh test objects in `audited` and `outside`. Verify the collector receives the scoped event with actor, object, audit ID and response status, excludes Secret bodies, and receives no event for the outside object.

## Constraints

Preserve TLS verification and the collector. Use `/etc/training/kubeconfig`. Do not write records directly to the collector log or change its implementation. The supplied reload helper installs your files and waits for the replacement API server; it does not choose the policy or credential for you.

## How the answer is checked

The grader creates unique disposable Secrets and reads only newly appended collector records. It requires successful delivery, useful metadata, no request/response body, and no record from the outside namespace. The receiver runs outside the control-plane container; durable external storage and disaster recovery are outside this lab.
