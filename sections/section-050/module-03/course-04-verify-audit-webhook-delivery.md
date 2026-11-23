---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Verify Delivery To An Audit Webhook

The log backend of the kube-apiserver writes audit events to a file on the control-plane node. If the node is lost or an attacker controls it, that file is lost or can be changed. The webhook backend sends the same events over HTTPS to a separate receiver. A configured address does not prove delivery, so this lesson checks the receiving side.

## The two input files

The webhook backend reads a kubeconfig file. A kubeconfig file names a server address, the CA (certificate authority) certificate that verifies the server's TLS (Transport Layer Security) certificate, and the credential to send. The kube-apiserver reads it from `--audit-webhook-config-file` and the audit policy from `--audit-policy-file`. Both flags are read only when the kube-apiserver starts.

The lab VM for this lesson runs a one-node kubeadm cluster. The kube-apiserver sends audit events to `audit-collector.service`, an HTTPS receiver on `127.0.0.1:8443` that runs as a systemd service on the VM, outside the kube-apiserver Pod. The receiver accepts only the bearer token `training-audit-token` and writes each event it accepts to `/var/log/audit-collector/events.jsonl`. Open a shell on the VM with `astrona ssh astro-ats-036-lab-050-03-02` when the lab starts.

<!-- astrona:playground:renew -->

Look at the two files and the receiver:

```sh
sudo cat /etc/kubernetes/audit/webhook.yaml
sudo cat /etc/kubernetes/audit/policy.yaml
sudo systemctl status audit-collector.service --no-pager
```

The webhook file sends the token `incorrect-token`, so the receiver answers each batch with HTTP status 401. The policy has only `level: None`, so the kube-apiserver records nothing. Both files need a fix.

## Fix the credential and the policy

Change only the token line, and keep the server address and `certificate-authority-data`, so that the kube-apiserver still checks the receiver's certificate:

```sh
sudo sed -i 's/^    token: incorrect-token$/    token: training-audit-token/' /etc/kubernetes/audit/webhook.yaml
```

The kube-apiserver checks the rules of a policy in order and uses the first rule that matches. The first rule below records Secrets and ConfigMaps of one namespace at `Metadata`: who did what to which object, and the response code, but no request or response body. The last rule records everything else at `None`. `omitStages` drops the `RequestReceived` stage, so each request leaves one `ResponseComplete` event instead of two.

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

The kubelet replaces a static Pod only when its manifest changes, and here only the two input files changed. Stop the kube-apiserver container with crictl, the command-line client of the container runtime. The kubelet then starts a new container from the same manifest, and that container reads the new files:

```sh
sudo crictl stop "$(sudo crictl ps --name '^kube-apiserver$' -q)"
kubectl get --raw=/readyz
```

For a short time kubectl cannot reach the kube-apiserver. Run the second command again until it prints `ok`.

## Test the delivery

Create test objects with distinct names in the scoped namespace and in another namespace, then read the newest receiver lines:

```sh
kubectl -n starfleet-036-050-03-02 create secret generic student-audit-proof --from-literal=value=disposable-training-value
kubectl -n outpost-036-050-03-02 create secret generic student-outside-proof --from-literal=value=disposable-training-value
sleep 2
sudo tail -n 20 /var/log/audit-collector/events.jsonl
kubectl -n starfleet-036-050-03-02 delete secret student-audit-proof
kubectl -n outpost-036-050-03-02 delete secret student-outside-proof
```

The kube-apiserver sends a batch at least once a second (`--audit-webhook-batch-max-wait=1s`), so two seconds are enough. Find the create event of `student-audit-proof` with its `auditID`, `user.username`, `objectRef`, `stage: ResponseComplete` and the status code 201. Neither `requestObject` nor `responseObject` appears, the value `disposable-training-value` appears nowhere, and the outside object has no event.

You now know how to fix the credential and the scope of the webhook backend and how to prove delivery with a fresh event. The open question is what the receiver must do with the events after they arrive.

## Common pitfalls

> [!WARNING]
> An empty receiver log can mean a wrong policy, a rejected token, broken TLS or a stopped receiver. Require a fresh positive event before you read meaning into an absent one. This local delivery test does not prove durable retention, access control on the receiver, or survival of a full VM failure.
