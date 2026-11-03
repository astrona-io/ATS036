---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Summary

The Kubernetes API server handles every request to run a command in a Pod or to forward a port to it. These requests use subresources of the `pods` resource, `pods/exec` and `pods/portforward`. An audit policy rule that lists only `pods` does not match them, so the policy must name each subresource. At the level `Metadata`, an event records the verb, the resource, the subresource, the Pod name, the namespace, the stage, the identity, the source address, the client and the request address, without request or response bodies.

An `exec` request is a `create` on `pods/exec`. The requested command appears as `command=` parameters in the request address. A request can produce events for more than one stage, and the audit identifier ties them together. The event proves that an identity asked for a session in a Pod. It does not prove what the command did.

The identity in a record is an authenticated account: a user from a certificate, a group member, a ServiceAccount, or a caller that impersonated another identity. It is not a person, and shared credentials hide the person. The source address and the client name help to judge whether the request fits normal use, but proxies change what the API server sees.

An investigation connects the record with other evidence by time, Pod, node and container identifier. The baseline of the workload decides whether the request needs an explanation. A missing record never proves that nothing happened, because the policy may not cover the behavior and the log can be changed. A finding binds a conclusion to an audit identifier and a stage and leaves the request content out. The key facts to remember are these:

- List `pods/exec` and `pods/portforward` in the audit policy by name.
- The record proves a request and an identity, not the effect of the command.
- Read both `user` and `impersonatedUser`.
- Keep a copy of the audit log outside the cluster.

<!-- astrona:playground:destroy -->
