---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Deliver Audit Metadata Outside The Control Plane

Allow about 15 minutes for the tasks.

An audit log that stays inside the control plane is lost with the node, and an attacker on the node can change it. The kube-apiserver in this lab already sends audit events to a collector outside its Pod, but the collector rejects them and the policy records nothing. Make the scoped events arrive, and only those.

Solve this question on: `terminal`

## Starting state

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The kube-apiserver runs as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`, with these audit flags:

- `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`: the audit policy, the rules that decide which requests are recorded and at which level.
- `--audit-webhook-config-file=/etc/kubernetes/audit/webhook.yaml`: the webhook backend, a kubeconfig file that names the HTTPS address, the CA (certificate authority) certificate and the token the kube-apiserver sends with each batch of events.
- `--audit-webhook-batch-max-wait=1s`: the kube-apiserver sends a batch at least once a second.

The collector is the systemd service `audit-collector.service` on the VM, outside the kube-apiserver Pod. It listens with TLS (Transport Layer Security) on `https://127.0.0.1:8443/audit`, accepts only the bearer token `training-audit-token` and appends each event as one JSON line to `/var/log/audit-collector/events.jsonl`. The webhook file sends the token `incorrect-token`, and the policy has the single rule `level: None`. The namespaces `starfleet-036-050-03-02` and `outpost-036-050-03-02` exist.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-050-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-050-03-02`. You are logged in as the `student` user. The files in `/etc/kubernetes` belong to root, so run node commands with `sudo`.

## Tasks

1. In `/etc/kubernetes/audit/webhook.yaml`, set the user token to `training-audit-token`. Keep the server address and the `certificate-authority-data`, and do not add `insecure-skip-tls-verify`.
2. Replace `/etc/kubernetes/audit/policy.yaml` with a policy that records Secrets and ConfigMaps (core API group) in `starfleet-036-050-03-02` at level `Metadata`, records nothing else (`level: None`) and omits the stage `RequestReceived`.
3. Make the kube-apiserver load both files. Keep the audit flags and the mount of `/etc/kubernetes/audit`, and do not change the collector or write to its log file.

## Constraints

Keep TLS verification, `audit-collector.service` and its log file as they are. Do not write events to the collector log by hand. Work only in the namespaces `starfleet-036-050-03-02` and `outpost-036-050-03-02`. A kube-apiserver restart adds a short wait.

## How the answer is checked

Each check gives one point: with the right token and a verified TLS certificate, fresh create events of the scoped namespace reach the collector outside the kube-apiserver Pod; the collector receives only Metadata events for Secrets and ConfigMaps of `starfleet-036-050-03-02`, with no bodies, no `RequestReceived` stage and nothing from `outpost-036-050-03-02`.

Create one Secret in each namespace, wait two seconds and read the newest collector lines:

```sh
kubectl -n starfleet-036-050-03-02 create secret generic check-scoped --from-literal=value=check-value
kubectl -n outpost-036-050-03-02 create secret generic check-outside --from-literal=value=check-value
sleep 2
sudo tail -n 5 /var/log/audit-collector/events.jsonl
```

Only `check-scoped` appears, with the level `Metadata` and the stage `ResponseComplete`, and `check-value` appears nowhere. The grader creates its own Secrets and ConfigMaps in both namespaces with a random value and reads only the lines that arrive after them.
