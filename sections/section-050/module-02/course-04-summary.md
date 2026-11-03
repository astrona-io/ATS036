---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Summary

Interactive access to a Pod reaches the API server as a request to a subresource: `pods/exec` runs a command, `pods/attach` joins a process, `pods/portforward` opens a tunnel and `pods/log` reads a log. An audit policy compares resource names in full, so a rule for `pods` does not record any of them. Each subresource must be listed by name, or matched with `pods/*`.

An exec event holds the identity in `user`, the Pod in `objectRef`, and the command, the container and the stream options in `requestURI`. The verb depends on the client, `create` for a `POST` request and `get` for a WebSocket request, so filters use the subresource and not the verb. A long-running request can produce a `ResponseStarted` event and a `ResponseComplete` event with the same `auditID`.

The audit log proves that an identity asked to run a command and whether the API server accepted the request. It does not hold the output or the input of the session, and it cannot show what a user did inside a shell. A runtime sensor on the node covers that part.

A good policy puts narrow rules first, records interactive subresources at the `Metadata` level, drops known noise by user, and keeps bodies that can hold credentials out of the file. The first matching rule wins, and a request that matches no rule leaves no record.

Key facts:

- `pods` does not match `pods/exec`; list the subresource.
- Exec records have `objectRef.subresource` set to `exec`.
- The command is in the `requestURI` query string.
- The log does not hold the session output.
- Token requests are recorded at `Metadata`.

<!-- astrona:playground:destroy -->
