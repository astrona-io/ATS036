---
draft: true
---
# Solution

Install the scoped Metadata policy and credential:

```sh
sudo tee /etc/training/audit-policy.json >/dev/null <<'POLICY'
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
POLICY
sudo python3 - <<'TOKEN'
import json,pathlib
p=pathlib.Path('/etc/training/audit-webhook.json');obj=json.loads(p.read_text());obj['users'][0]['user']['token']='training-audit-token';p.write_text(json.dumps(obj,indent=2)+'\n')
TOKEN
sudo reload-training-audit
```

Create distinct test objects in both namespaces and inspect new collector records as shown in the preparation lesson. Keep Secret bodies out of audit events.
