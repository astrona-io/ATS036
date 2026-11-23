---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Deliver Audit Metadata Outside The Control Plane Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-050-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-050-03-02`. The files in `/etc/kubernetes` belong to root, so the commands below use `sudo`.

## Fix the token

The webhook file is a kubeconfig file. Its `clusters` entry gives the collector address and the CA certificate that the kube-apiserver uses to check the collector's TLS certificate. Its `users` entry gives the bearer token that the kube-apiserver sends in the `Authorization` header. The collector answers every batch with the wrong token with HTTP status 401, so no event is stored.

Change only the token line:

```sh
sudo sed -i 's/^    token: incorrect-token$/    token: training-audit-token/' /etc/kubernetes/audit/webhook.yaml
sudo grep -n 'token:' /etc/kubernetes/audit/webhook.yaml
```

The second command prints the token line with `training-audit-token`. The server address and `certificate-authority-data` stay as they were, so the kube-apiserver still checks the certificate of the collector.

## Write the scoped policy

The kube-apiserver checks the rules of an audit policy in order and uses the first rule that matches a request. The first rule below matches Secrets and ConfigMaps in one namespace and records them at `Metadata`: the user, the verb, the object and the response code, but no request or response body. The last rule records everything else at `None`. `omitStages` drops the `RequestReceived` stage, so each request leaves one `ResponseComplete` event.

Save this as `policy-audit.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  namespaces: ["starfleet-036-050-03-02"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: None
```

Copy it over the policy file:

```sh
sudo cp policy-audit.yaml /etc/kubernetes/audit/policy.yaml
```

## Restart the kube-apiserver

The kube-apiserver reads the policy and the webhook file only when it starts. The manifest did not change, so the kubelet does not replace the Pod on its own. Stop the kube-apiserver container with crictl, the command-line client of the container runtime. The kubelet then starts a new container from the same static Pod manifest:

```sh
sudo crictl stop "$(sudo crictl ps --name '^kube-apiserver$' -q)"
sudo crictl ps --name '^kube-apiserver$'
kubectl get --raw=/readyz
```

Run the last two commands again until `crictl ps` shows a new container ID and `kubectl get --raw=/readyz` prints `ok`. For a short time kubectl cannot reach the kube-apiserver, so the first tries can fail.

## Test the delivery

Create one Secret in each namespace and read the collector lines that follow:

```sh
kubectl -n starfleet-036-050-03-02 create secret generic check-scoped --from-literal=value=check-value
kubectl -n outpost-036-050-03-02 create secret generic check-outside --from-literal=value=check-value
sleep 2
sudo tail -n 5 /var/log/audit-collector/events.jsonl
```

The create event of `check-scoped` has `"level": "Metadata"`, `"stage": "ResponseComplete"`, an `auditID`, the user in `user.username`, the object in `objectRef` and `"code": 201` in `responseStatus`. No line names `check-outside`, and `check-value` appears in no line. Delete both test Secrets when you are done.
