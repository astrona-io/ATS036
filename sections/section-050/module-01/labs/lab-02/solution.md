---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Send A Denied Secret Read And Find Its Audit Record Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-050-01-02" || exit 1
node_name="astro-ats-036-lab-050-01-02-control-plane"
```

Keep this connection for the whole task. The variable `node_name` holds the name of the control plane node container, where the API server writes the audit log.

## Check what the policy records

An audit policy is the file that tells the API server which requests to write to the audit log and at which level. A request that no rule selects leaves no record, so check the policy before you send the request:

```sh
podman exec "$node_name" cat /etc/kubernetes/training-audit-policy.json
```

<!-- CAPTURE: l1-policy -->

The first rule selects requests for `secrets` in `starfleet-036-050-01-02` at the level `Metadata`. That level writes who sent the request, what it asked for and the result, but no request body and no response body. The last rule drops everything else with `level: None`. A read of `navigation-key` therefore leaves one record, whether the API server allows it or denies it.

## Send the denied read

Impersonation means that a client asks the API server to handle a request as another identity. The `--as` option of `kubectl` adds the header `Impersonate-User` to the request. The API server first checks that the real caller may impersonate that identity. The cluster administrator from your kubeconfig has that permission. The authorizer then checks the request itself as the impersonated identity, here the ServiceAccount `drifter`. A ServiceAccount username has the form `system:serviceaccount:<namespace>:<name>`.

Send the read as `drifter`. The command fails on purpose, so run it on its own and not in a script that stops on errors:

```sh
kubectl -n starfleet-036-050-01-02 get secret navigation-key --as=system:serviceaccount:outpost-036-050-01-02:drifter
```

<!-- CAPTURE: l1-denied-read -->

The API server answered with `Forbidden`, which is the HTTP status code 403. The message names the impersonated ServiceAccount, not the administrator, because the authorizer checked the request as `drifter`. `drifter` has no Role or RoleBinding, so the role-based access control (RBAC) authorizer found no rule that allows the `get`.

## Find the record of that request

The audit log is a file of JSON lines on the control plane node. Each line is one event. The log already holds two other reads of `navigation-key`: an allowed read by the administrator and a denied read as the `default` ServiceAccount of `outpost-036-050-01-02`. A search for the Secret name alone finds all three, so print the fields that tell them apart. Save this as `find-denied-read.py`:

```python
import json
import sys

for line in sys.stdin:
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if event.get("stage") != "ResponseComplete" or reference.get("resource") != "secrets":
        continue
    print(
        event["auditID"],
        event["user"]["username"],
        event.get("impersonatedUser", {}).get("username", "-"),
        event["verb"],
        reference.get("name", "-"),
        event.get("responseStatus", {}).get("code", "-"),
    )
```

The script keeps the `ResponseComplete` events for Secrets. That stage holds the final status code. For each event it prints the `auditID`, the caller, the impersonated user, the verb, the Secret name and the status code. Run it on the log:

```sh
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 find-denied-read.py
```

<!-- CAPTURE: l1-find-record -->

Each line starts with an `auditID`, which is a random ID that the API server gives to each request. Your IDs are different. The line you need has `system:serviceaccount:outpost-036-050-01-02:drifter` in the third column and `403` in the last. Its second column is still the administrator. The `user` field always holds the identity that authenticated, and the `impersonatedUser` field holds the identity that the authorizer checked. A report that names only one of them tells half the story.

Copy the `auditID` of that line into a variable and print the whole record:

```sh
audit_id="<AUDIT_ID>"
podman exec "$node_name" grep -F "$audit_id" /var/log/training-audit/audit.jsonl | python3 -m json.tool
```

<!-- CAPTURE: l1-full-record -->

The record shows `stage` `ResponseComplete`, `verb` `get`, `objectRef.name` `navigation-key` and `responseStatus.code` `403`. The annotation `authorization.k8s.io/decision` is `forbid`, which the authorizer set. The record has no `requestObject` and no `responseObject`, because the policy level is `Metadata`.

## Record the evidence

Write the four values into a ConfigMap. Replace `<AUDIT_ID>` with the value of `$audit_id` and `<USER>` with the `user.username` of the record. Save this as `configmap-denied-read-report.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: denied-read-report
  namespace: starfleet-036-050-01-02
data:
  auditID: <AUDIT_ID>
  user: <USER>
  impersonatedUser: system:serviceaccount:outpost-036-050-01-02:drifter
  code: "403"
```

The quotes around `403` keep it a string. A ConfigMap stores only strings in `data`, and `kubectl` refuses a plain number there. Apply it:

```sh
kubectl apply -f configmap-denied-read-report.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-050-01-02 get configmap denied-read-report -o jsonpath='{.data}{"\n"}'
```

<!-- CAPTURE: l1-report -->

The ConfigMap now ties the report to one request in the log. The grader reads the log on the node, finds the record with that `auditID` and compares the user and the impersonated user with your values. The policy does not select ConfigMaps, so creating the report adds no record to the log.

You now know how to send a request as another identity, find its record among similar ones and read the two identity fields. The open question for a real cluster is what a burst of such records means. One denied read is a test; many from one ServiceAccount against many Secrets can be a stolen token in use.

When you are done, remove the lab with `astrona destroy ats-036-lab-050-01-02`.

## Common pitfalls

> [!WARNING]
> - **Reporting the impersonated identity as the user.** `user.username` is the identity that authenticated, here the administrator. The ServiceAccount is in `impersonatedUser.username`.
> - **Picking the wrong denied read.** The `default` ServiceAccount also has a 403 record for `navigation-key`. Check the impersonated user, not only the code.
> - **Writing `code: 403` without quotes.** The ConfigMap `data` field takes only strings, so `kubectl apply` fails.
> - **Giving `drifter` a Role to "fix" the error.** The task asks for a denied request. A 200 record does not count.
> - **Stopping a script on the failed command.** A denied `kubectl get` exits with a nonzero status. Run it on its own line.
