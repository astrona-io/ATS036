---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Summary

The Kubernetes audit system records requests to the API server as JSON events. Each event belongs to a stage of the request, and `ResponseComplete` carries the final status code. The level of a rule decides how much an event holds: `None` writes nothing, `Metadata` writes who, what, when and the result, `Request` adds the request body, and `RequestResponse` adds the response body as well.

An audit policy selects the requests to record. The API server checks the rules from top to bottom, and the first matching rule sets the level. A request that matches no rule is not recorded, and a resource name such as `pods` does not match a subresource such as `pods/exec`. A good policy drops noisy requests early, records sensitive objects at `Metadata`, records `exec` and ends with a broad `Metadata` rule.

Auditing is enabled with flags on the API server. `--audit-policy-file` loads the policy and `--audit-log-path` sets the log file. The rotation flags `--audit-log-maxage`, `--audit-log-maxbackup` and `--audit-log-maxsize` limit disk use. The webhook backend sends events to a remote collector in `batch`, `blocking` or `blocking-strict` mode. In a static Pod, the policy file and the log directory need `hostPath` volumes and mounts. A missing mount or a wrong path leads to a failed start or an empty log.

For access monitoring, the useful fields are the user, the impersonated user, the verb, the object reference, the source address and the status code. A denied request is as valuable as an allowed one. Secrets belong at the `Metadata` level, because a higher level writes encoded credentials into a file that many people can read.

Key facts:

- Four stages: `RequestReceived`, `ResponseStarted`, `ResponseComplete`, `Panic`.
- Four levels: `None`, `Metadata`, `Request`, `RequestResponse`.
- The first matching rule wins.
- `omitStages` removes stages such as `RequestReceived`.
- The log shows the real caller in `user` and the acting identity in `impersonatedUser`.

<!-- astrona:playground:destroy -->
