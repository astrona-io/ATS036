---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Who Sent The Request: Identity And Origin

An audit record is only useful for an investigation if it points to an identity. The API server authenticates every request before it handles it, and it writes the result into the record. This part reads the fields that identify the sender and shows what each one proves.

## Identity fields

The `user` object of an event describes the authenticated identity:

- `username` is the name of the user. A person who signs in with a client certificate appears with the common name of the certificate. A ServiceAccount appears as `system:serviceaccount:<namespace>:<name>`.
- `groups` lists the groups of the identity. A client certificate carries its groups in the organization field, and the group `system:masters` gives the identity cluster-wide administrator rights.
- `extra` can hold more attributes from the authentication method.

The event can also contain `impersonatedUser`. A client with the `impersonate` permission can send a request as another user, and then `user` holds the real caller and `impersonatedUser` holds the identity that was used for authorization. Look at both fields.

The identity is an account, not a person. If several people share one kubeconfig file, the record names the shared account.

## Origin fields

Two fields describe where the request came from. `sourceIPs` lists the client address and, when a proxy forwarded the request, the addresses of the proxies. `userAgent` is the name of the client program, for example `kubectl` followed by its version. A `userAgent` that is not `kubectl` and not a known controller is worth a look.

Print the identity and origin fields of the `exec` requests. Save this as `identity-report.py`:

```python
import json
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("subresource") != "exec":
        continue
    user = event.get("user", {})
    print(
        event.get("auditID"),
        user.get("username"),
        user.get("groups"),
        event.get("impersonatedUser"),
        event.get("sourceIPs"),
        event.get("userAgent"),
    )
```

Run it against the audit log:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-010-03)"
node_name="astro-ats-036-playground-010-03-control-plane"
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 identity-report.py
```

Compare the user with the identity of your own kubeconfig. The request that setup ran uses the same cluster administrator credentials as your shell, so the `username` and the groups match yours. This is expected in the playground. In a real cluster, a cluster administrator who starts a shell in a production Pod is normal only when someone approved the maintenance.

## From the record to a finding

A finding binds a conclusion to evidence that someone else can look up. A useful finding names the user, the verb, the resource, the subresource, the namespace, the Pod, the stage, the `auditID` and the `requestURI`. It does not copy request or response bodies. The next task asks you to write such a finding as a ConfigMap, because a stored finding can be checked against the log.

The reader now knows how to name the sender of a request. What remains is to connect the request with the rest of the evidence.

## Common pitfalls

> [!WARNING]
> - **Naming a person from a username.** The record names an account. Shared credentials hide the person.
> - **Ignoring `impersonatedUser`.** The caller and the impersonated identity are different accounts with different permissions.
> - **Trusting `sourceIPs` as a physical location.** Proxies, load balancers and node address translation change what the API server sees.
> - **Copying a request body into the finding.** The body can contain secret data. Keep the report to metadata.
