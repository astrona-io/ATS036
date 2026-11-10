---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Actor Identity In Audit Records

Every audit event names an actor, but the name is only the identity that the API server authenticated. It is not the person, and it is not always the Pod. If you write "Alice stole the Secret" because a record shows the user `alice`, you may be wrong, and the real source stays unseen. This part reads the identity fields of an audit event and states what each one proves.

## Kinds of identity

Kubernetes has no User or Group objects. The authenticator, the part of the API server that checks credentials, produces a user name and a list of groups for each request. The common kinds are:

- **A human user.** The name comes from a client certificate or from an OIDC (OpenID Connect) token. The group `system:masters` carries unlimited rights.
- **A ServiceAccount.** The name is `system:serviceaccount:<namespace>:<name>`. Its groups include `system:serviceaccounts` and `system:serviceaccounts:<namespace>`.
- **A node.** The kubelet authenticates as `system:node:<node name>` in the group `system:nodes`.
- **Anonymous.** A request without credentials is `system:anonymous`.

A request can also carry **impersonation**. A user with the `impersonate` permission can send the headers `Impersonate-User` and `Impersonate-Group`. The audit event then records two identities: `user` is the real caller, and `impersonatedUser` is the identity used for authorization. A record that shows only the impersonated name hides the real actor, so read both fields.

## The fields of an event

Besides `user.username`, an audit event holds more fields that help you attribute a request:

- `user.groups` lists the groups of the caller.
- `user.extra` holds extra attributes. For a token that was projected into a Pod, these attributes include the Pod name and the Pod UID, with the keys `authentication.kubernetes.io/pod-name` and `authentication.kubernetes.io/pod-uid`.
- `sourceIPs` lists the addresses the API server saw. Proxies and load balancers can change the first one.
- `userAgent` is the name that the client program sends. The caller chooses it, so it is a hint, not proof.
- `annotations` holds the authorization decision, for example `authorization.k8s.io/decision` with the value `forbid`.

A ServiceAccount token that is projected into a Pod is bound to that Pod. The API server can therefore tell which Pod the token was issued for, and `user.extra` records it. A token created with `kubectl create token` is not bound to a Pod, so the extra fields do not name one.

## Read the identity of the denied request

The playground audit log is on the control plane node. Select the cluster and save a small program that prints identity fields for all events of one user:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-030-01)"
node_name="astro-ats-036-playground-030-01-control-plane"
```

Save this as `audit-actor.py`:

```python
import json
import sys

wanted_user = sys.argv[1] if len(sys.argv) > 1 else ""

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    user = event.get("user", {})
    if wanted_user not in user.get("username", ""):
        continue
    reference = event.get("objectRef", {})
    status = event.get("responseStatus", {})
    print("auditID:", event.get("auditID"))
    print("stage:", event.get("stage"), "code:", status.get("code"))
    print("request:", event.get("verb"), event.get("requestURI"))
    print("resource:", reference.get("resource"), reference.get("name"))
    print("username:", user.get("username"))
    print("groups:", user.get("groups"))
    print("extra:", user.get("extra"))
    print("sourceIPs:", event.get("sourceIPs"))
    print("userAgent:", event.get("userAgent"))
    print()
```

Run it on the audit log, filtered to the `threat-reader` ServiceAccount:

```sh
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 audit-actor.py threat-reader
```

Every block is one request. Check the fields of the last block against what you know. The `username` is `system:serviceaccount:starfleet:threat-reader`, the `groups` include `system:serviceaccounts:starfleet`, and the request is a `get` on `/api/v1/namespaces/starfleet/secrets/audit-token` with the code `403`. The `userAgent` names Python's `urllib` library, because the request program in the Pod uses it.

## Tie the identity to a Pod

Now compare the record with the live objects. The first command prints the IP address and the UID of `threat-client`:

```sh
kubectl -n starfleet get pod threat-client -o jsonpath='{.status.podIP}{" "}{.metadata.uid}{"\n"}'
```

Record the live Pod IP and the audit source address separately. NAT or a proxy can make them differ, so an address mismatch alone does not disprove the credential binding. Compare `authentication.kubernetes.io/pod-name` and `authentication.kubernetes.io/pod-uid` in `user.extra` with the live Pod. These attributes identify the Pod that received the token; they do not prove that the token was never copied elsewhere. The UID distinguishes this instance from a replacement with the same name.

## What the identity proves

The record proves that someone or something presented valid credentials for `threat-reader` and asked for the Secret. It does not prove who wrote the code in the Pod. It does not show how that code arrived. It proves nothing about a human, because a ServiceAccount has no person behind it in the record. For a human user name, the record shows the credential holder, and a stolen certificate looks the same as the real owner.

State the finding with the limits: "ServiceAccount `threat-reader`, Pod `threat-client`, UID `<uid>`, requested `get secrets/audit-token`, denied with `403`, audit ID `<auditID>`." The practice task on the next page asks for exactly this kind of finding. Afterwards, the timeline shows how this event fits with others.

## Common pitfalls

> [!WARNING]
> - **Naming a person from a ServiceAccount record.** The record has no human identity.
> - **Ignoring `impersonatedUser`.** The real caller is in `user`. The identity used for authorization is the impersonated one.
> - **Trusting `userAgent`.** The client sets it, and an attacker can change it.
> - **Using the Pod name as the key.** Names are reused. Use the Pod UID or the `auditID`.
