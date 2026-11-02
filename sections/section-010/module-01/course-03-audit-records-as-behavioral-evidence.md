---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Audit Records As Behavioral Evidence

A runtime sensor watches processes on a node. The Kubernetes API server watches something different: every request that a user or a workload sends to the API. A workload that uses its ServiceAccount token to list or read Secrets leaves no syscall that looks unusual, but it leaves an audit record. This part finds one such record in the playground, a request that the API server denied, and reads it field by field.

## What an audit record contains

The Kubernetes API server handles every request in stages, and it can write an audit event at each stage. The kube-apiserver, the control plane component that exposes the API, writes these events to the audit backend. The playground uses a log backend, which writes one JSON object per line to a file on the control plane node: `/var/log/training-audit/audit.jsonl`.

An event answers who did what to which object, and what the result was. The fields you need first are:

- `auditID` is a unique ID for one request. All stages of the request carry the same value.
- `stage` is the stage of request handling that produced this event. `ResponseComplete` means the response was sent.
- `verb` is the API verb: `get`, `list`, `create`, `update`, `patch`, `delete` and others.
- `user.username` is the authenticated identity. A ServiceAccount appears as `system:serviceaccount:<namespace>:<name>`.
- `sourceIPs` and `userAgent` say where the request came from and which client sent it.
- `objectRef` names the resource, namespace and object name.
- `responseStatus.code` is the HTTP status code of the answer. `403` means the request was authenticated and then denied by authorization.

An audit event tells you about the API request. It does not tell you what the process did in the container. That limit decides how you use it in an investigation.

## Read the policy that decides what is recorded

The audit policy tells the API server which requests to record and how much detail to keep. The playground policy is a JSON file on the control plane node. Read it:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-010-01)"
node_name="astro-ats-036-playground-010-01-control-plane"
podman exec "$node_name" cat /etc/kubernetes/training-audit-policy.json
```

The policy has `apiVersion` `audit.k8s.io/v1` and the global setting `omitStages` with the stage `RequestReceived`, so only later stages are written. It has two rules. The first rule uses the level `Metadata` for the resources `secrets`, `configmaps` and `pods` in the namespace `starfleet`. The last rule uses the level `None`, so every other request is not recorded. The API server checks the rules in order and uses the first rule that matches.

The level `Metadata` records who, what, when and the result, but not the request body or the response body. That is why the audit log can be used as evidence of a Secret read without storing the Secret.

## Trigger and find the denied request

The `threat-client` Pod runs as the `threat-reader` ServiceAccount, and the script `/app/request.py` in it tries to read the Secret `audit-token` through the API. The playground start-up already ran it once. Run it again so you know the request is fresh:

```sh
kubectl -n starfleet exec threat-client -- python /app/request.py
```

The script prints `denied-secret-read`. It prints this text only when the API server answers with status `403`. Now search the audit log for the denial. The `grep` filters the lines that contain the status code `403`, and the Python program prints the fields from the section above.

Save this as `audit-report.py`:

```python
import json
import sys

wanted_user = sys.argv[1] if len(sys.argv) > 1 else ""

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    username = event.get("user", {}).get("username", "")
    if wanted_user not in username:
        continue
    reference = event.get("objectRef", {})
    status = event.get("responseStatus", {})
    print(
        event.get("stageTimestamp"),
        event.get("auditID"),
        event.get("stage"),
        username,
        event.get("verb"),
        reference.get("resource"),
        reference.get("namespace"),
        reference.get("name"),
        status.get("code"),
    )
```

Run it against the log from the node:

```sh
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 audit-report.py threat-reader
```

Each line is one audit event of the `threat-reader` ServiceAccount. You should see one or more lines with the verb `get`, the resource `secrets`, the namespace `starfleet`, the name `audit-token`, the stage `ResponseComplete` and the code `403`. There is one such line for each time the script ran. The `auditID` value is different for every request. You need the exact value when you write a finding that someone else must be able to look up.

To read the whole record for the last denial, print the last matching line of the file:

```sh
podman exec "$node_name" grep '"code":403' /var/log/training-audit/audit.jsonl | tail -n 1
```

The JSON object has `requestURI` `/api/v1/namespaces/starfleet/secrets/audit-token`, `user.username` `system:serviceaccount:starfleet:threat-reader`, and an `annotations` object with `authorization.k8s.io/decision` set to `forbid`. There is no `requestObject` and no `responseObject`, because the level is `Metadata`.

## What the record proves

The record proves that the API server received a request from the `threat-reader` identity for this Secret and denied it. It does not prove that the data was read, because the answer was `403`. It does not prove who was behind the request, only that the Pod's token was used. Finally, the audit log says nothing about the process in `threat-client`. The sensor from the previous part and the audit log together show both sides: the process that sent the request, and the API's decision.

Falco can also read Kubernetes audit events. Its `k8saudit` plugin treats the audit stream as an event source, so the same rule language can alert on API behavior such as a Secret read by an unexpected ServiceAccount. A denied request is one thing to alert on. A burst of denied requests from one ServiceAccount is a stronger signal of discovery behavior.

## Common pitfalls

> [!WARNING]
> - **Reading a `403` as a successful read.** A denied request returns no data. Check `responseStatus.code` before you write a finding.
> - **Using `RequestReceived` as the final result.** That stage has no response status. Look at `ResponseComplete`, which the playground policy keeps.
> - **Identifying the actor by Pod name.** The log names the authenticated user. Several Pods can use one ServiceAccount, so the Pod name must come from `sourceIPs`, the `user.extra` field or other evidence.
> - **Losing the `auditID`.** A finding without the `auditID` cannot be matched to the record later.
