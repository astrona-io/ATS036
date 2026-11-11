---
draft: true
---
# Verify Delivery To An Audit Webhook

The audit log backend writes on the control-plane host. The webhook backend sends events to a separate receiver using a kubeconfig-style endpoint, certificate authority and credential. A configured URL does not prove delivery. This independent VM puts the receiver in a systemd service outside the kind control-plane container so you can inspect the receiving side.

<!-- astrona:playground:renew -->

Inside the VM, inspect the two input files and collector health:

```sh
export KUBECONFIG=/etc/training/kubeconfig
cat /etc/training/audit-policy.json
sudo systemctl status training-audit-collector --no-pager
```

Edit `/etc/training/audit-webhook.json`, setting its existing user's `token` to the disposable credential `training-audit-token`. Keep the HTTPS address and `certificate-authority-data`. Save this policy as `/etc/training/audit-policy.json`:

```json
{
  "apiVersion": "audit.k8s.io/v1",
  "kind": "Policy",
  "omitStages": [
    "RequestReceived"
  ],
  "rules": [
    {
      "level": "Metadata",
      "namespaces": [
        "audited"
      ],
      "resources": [
        {
          "group": "",
          "resources": [
            "secrets",
            "configmaps"
          ]
        }
      ]
    },
    {
      "level": "None"
    }
  ]
}
```

Rules are evaluated in order. The scoped Metadata rule records who did what without serializing Secret bodies; the final None rule excludes unrelated traffic. `omitStages` avoids a second RequestReceived record for each request.

Load the inputs and wait for the replacement API server:

```sh
sudo reload-training-audit
```

The helper copies the files into the owned kind node, mounts them into the API server, updates its audit flags and waits for a new ready instance. This restart is necessary because these startup inputs are not dynamically reloaded.

Create disposable test objects with distinct names:

```sh
kubectl -n audited create secret generic student-audit-proof --from-literal=value=disposable-training-value
kubectl -n outside create secret generic student-outside-proof --from-literal=value=disposable-training-value
sudo tail -n 20 /var/log/training-audit/events.jsonl
kubectl -n audited delete secret student-audit-proof
kubectl -n outside delete secret student-outside-proof
```

Allow a few seconds for the batch to arrive. Find the scoped creation's `auditID`, `user.username`, `objectRef`, `stage: ResponseComplete` and status code 201. Neither `requestObject` nor `responseObject` should appear, and the outside object's name should not be present. The receiver requires a bearer token and verifies transport through the configured CA; wrong credentials cause delivery failures without proving anything about policy scope.

## Common pitfalls

> [!WARNING]
> An empty receiver log can mean a wrong policy, failed authentication, broken TLS or an unavailable receiver. Require a fresh positive event before interpreting absence. This local delivery test does not establish durable retention, receiver access control for analysts, or survival of a complete VM failure.
