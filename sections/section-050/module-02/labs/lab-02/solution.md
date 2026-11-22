---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Fix An Audit Policy That Misses Pod Exec Requests Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-050-02-02" || exit 1
node_name="astro-ats-036-lab-050-02-02-control-plane"
```

Keep this connection for the whole task. The variable `node_name` holds the name of the control plane node container. The API server runs there as a static Pod, which is a Pod that the kubelet starts from a manifest file on the node, not from an object in the API.

## Find why exec leaves no record

An audit policy is a list of rules. The API server compares each request with the rules from the first to the last, and the first rule that matches sets the level. No later rule is read. Start with the symptom: run a command in the `shuttle` Pod, then count the exec records in the log:

```sh
kubectl -n starfleet-036-050-02-02 exec shuttle -- id
podman exec "$node_name" grep -c '"subresource":"exec"' /var/log/training-audit/audit.jsonl
```

<!-- CAPTURE: l2-exec-before -->

The command ran in the container, but the count is `0`. The API server handled the exec request and wrote nothing about it. Read the policy to see why:

```sh
podman exec "$node_name" cat /etc/kubernetes/training-audit-policy.json
```

<!-- CAPTURE: l2-policy-before -->

The policy has two faults. The first rule sets `level: None` for `pods/*`. That name matches every subresource of a Pod, so it also matches `pods/exec` and `pods/portforward`, and those requests stop there. The second rule was meant to record interactive access, but it names only `pods`. The audit system compares the full name, resource and subresource together, so `pods` never matches an exec request. Moving the second rule up would not help on its own, and fixing its name would not help either while the `None` rule stays above it.

## Write the corrected policy

The fix is one rule for `pods/exec` and `pods/portforward` at the level `Metadata`, placed above the `None` rule. The `None` rule stays, because it still drops the noisy Pod subresources. The kubelet, for example, sends a `pods/status` update each time a container in a Pod changes state. The `Metadata` level is enough for streaming requests: it records the user, the Pod and the `requestURI` with the command, and a streaming request has no body to record. Save this as `training-audit-policy.json`:

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
      "resources": [
        {
          "group": "",
          "resources": [
            "pods/exec",
            "pods/portforward"
          ]
        }
      ]
    },
    {
      "level": "None",
      "resources": [
        {
          "group": "",
          "resources": [
            "pods/*"
          ]
        }
      ]
    },
    {
      "level": "Metadata",
      "namespaces": [
        "starfleet-036-050-02-02"
      ],
      "resources": [
        {
          "group": "",
          "resources": [
            "secrets"
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

The rule that named only `pods` is gone, and the new rule has no `namespaces` filter, so it records exec and port-forward requests in every namespace. Copy the file to the path that the API server reads, then print it from the node to check that the copy arrived:

```sh
podman cp training-audit-policy.json "$node_name":/etc/kubernetes/training-audit-policy.json
podman exec "$node_name" head -n 20 /etc/kubernetes/training-audit-policy.json
```

<!-- CAPTURE: l2-policy-after -->

## Restart the API server

The API server reads the policy file only when it starts. A new file on the node changes nothing until the process restarts. The kubelet watches the directory `/etc/kubernetes/manifests` and runs one static Pod for each manifest in it. Move the API server manifest out of that directory, and the kubelet stops the API server. Check with `crictl`, the container runtime command-line tool on the node, that the container is gone:

```sh
podman exec "$node_name" mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/kube-apiserver.yaml
podman exec "$node_name" crictl ps --name kube-apiserver
```

<!-- CAPTURE: l2-apiserver-stopped -->

Run the `crictl` command again until it lists no `kube-apiserver` container. If you move the manifest back too early, the kubelet may never see that it was gone and keeps the old process. Then move the manifest back and wait, at most two minutes, until the new API server answers:

```sh
podman exec "$node_name" mv /etc/kubernetes/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
for attempt in $(seq 1 40); do kubectl --request-timeout=3s get --raw=/readyz && break; sleep 3; done
```

<!-- CAPTURE: l2-apiserver-ready -->

The loop prints errors while the API server starts and stops after the first `ok`. The kubelet started a new `kube-apiserver` container, and that process read the corrected policy file. If the loop never prints `ok`, the policy file has an error: the API server stops at start when it cannot read the policy. Fix the file and copy it again; the kubelet restarts the container by itself.

## Prove that both requests are recorded

A policy is only correct when a real request leaves a record. Save this as `audit-pod-access.py`. It reads events from standard input and prints one line for each event that names a Pod subresource:

```python
import json
import sys

for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("resource") != "pods" or not reference.get("subresource"):
        continue
    print(
        event["stage"],
        event["level"],
        event["user"]["username"],
        event["verb"],
        reference["subresource"],
        reference.get("name", "-"),
        event["requestURI"],
    )
```

Send one exec request and one port-forward session. `kubectl port-forward` keeps running, so start it in the background, send one HTTP request through the tunnel with `curl`, and stop it:

```sh
kubectl -n starfleet-036-050-02-02 exec shuttle -- id
kubectl -n starfleet-036-050-02-02 port-forward service/probe 18080:80 &
sleep 3
curl -s http://127.0.0.1:18080/
kill %1
```

<!-- CAPTURE: l2-requests-after -->

`kubectl port-forward` printed `Forwarding from 127.0.0.1:18080 -> 8080` after the API server accepted the connection, and the `probe` application answered the `curl` request through the tunnel. `kubectl` resolved the Service to one `probe` Pod, so the request went to the `portforward` subresource of that Pod. Now read the log:

```sh
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 audit-pod-access.py
```

<!-- CAPTURE: l2-report-after -->

The output has lines for the subresource `exec` with the Pod name `shuttle` and a `requestURI` that contains `command=id`, and lines for the subresource `portforward` with the name of the `probe` Pod. Every line has the level `Metadata`. A streaming request can leave two lines with the same request: `ResponseStarted` when the API server accepted the connection and `ResponseComplete` when it ended. No line names `log` or `status`, because the `None` rule still drops those subresources.

You now know how to read a policy as a first-match list, repair both the order and the names of its rules, and make the API server load the new file. The question still open is what happened inside the shell. The audit log records that `kubectl exec` started a command, not what the user typed in it; a runtime sensor on the node answers that.

When you are done, remove the lab with `astrona destroy ats-036-lab-050-02-02`.

## Common pitfalls

> [!WARNING]
> - **Fixing the file and skipping the restart.** The API server reads the policy only at start. Until it restarts, it keeps using the old rules.
> - **Moving the manifest back too quickly.** Wait until `crictl ps --name kube-apiserver` lists no container, or the kubelet may keep the old process.
> - **Adding the exec rule below the `None` rule.** The first matching rule wins, so the request never reaches it.
> - **Naming `pods` or `pods/*` in the recording rule.** `pods` misses every subresource, and `pods/*` at `Metadata` also records the `pods/status` noise.
> - **Breaking the JSON.** A missing comma stops the API server at start. Check the file before you copy it, for example with `python3 -m json.tool training-audit-policy.json`.
