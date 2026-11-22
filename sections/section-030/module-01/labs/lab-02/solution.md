---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Isolate A Compromised Pod And Revoke Its Token Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own kind cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-030-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The task is containment that keeps the evidence. Deleting the `threat-client` Pod would end the attack, but it would also remove the container state and logs. It would leave the long-lived token and the RoleBinding in place, so the attacker could come back with the same authority. The steps below isolate the Pod, then remove each source of authority one at a time, and leave the legitimate `probe-reader` identity alone.

## Look at the starting state

Start with the Pods and their labels. The label list matters, because the quarantine label and the NetworkPolicy both work through labels:

```sh
kubectl -n starfleet-036-030-01-02 get pods --show-labels
```

```text
NAME                    READY   STATUS    RESTARTS   AGE   LABELS
probe-89846ccb9-xr5jw   1/1     Running   0          5s    app=probe,pod-template-hash=89846ccb9
threat-client           1/1     Running   0          5s    app=threat-client
```

The output on this page comes from a test run of the lab. In your lab, the random parts differ: the name suffix of the `probe` Pod, the UIDs and the times.

The `threat-client` Pod is a bare Pod. A bare Pod is a Pod that no controller owns, so no ReplicaSet recreates it if it stops. The `probe` Pod belongs to the Deployment `probe` and runs as the ServiceAccount `probe-reader`. A ServiceAccount is the Kubernetes identity that a Pod uses when it sends requests to the API server.

## Confirm the Pod and add the quarantine label

A Pod name can be reused. If someone deletes `threat-client` and creates a new Pod with the same name, the new Pod holds none of the evidence. The UID (unique identifier) is different for every object the API server creates, so it tells the two apart. Compare the UID in the ticket with the UID of the live Pod:

```sh
kubectl -n starfleet-036-030-01-02 get configmap incident-ticket -o jsonpath='{.data.podUID}{"\n"}'
kubectl -n starfleet-036-030-01-02 get pod threat-client -o jsonpath='{.metadata.uid}{"\n"}'
```

```text
70e39f38-591a-4a30-88a8-80860ad33d9b
70e39f38-591a-4a30-88a8-80860ad33d9b
```

The two lines are the same, so the live Pod is the one under investigation. Your UID is different from the one shown here. Save the Pod object to a file on your host before you change anything, so the record holds the state from before containment:

```sh
kubectl -n starfleet-036-030-01-02 get pod threat-client -o yaml > threat-client-evidence.yaml
```

Now add the label. A label change is an update of the Pod metadata. The API server stores it and the kubelet does not restart the container, so the process and its state stay as they were:

```sh
kubectl -n starfleet-036-030-01-02 label pod threat-client incident=quarantine
```

The label by itself blocks nothing. It marks the Pod for the people who read the cluster, and it gives the NetworkPolicy in the next step something to select.

## Cut the network traffic with a NetworkPolicy

A NetworkPolicy is a Kubernetes object that says which traffic may reach or leave the Pods it selects. The network plugin of the cluster enforces it, not the API server. The network plugin of this kind cluster is kindnet, and kindnet enforces NetworkPolicy. When a policy selects a Pod and lists a direction in `policyTypes` without any rule for that direction, the network plugin drops all traffic in that direction.

First test the traffic of the Pod, so you can compare it after the change. A DNS (Domain Name System) lookup of the API server Service is a small request that leaves the Pod and goes to the cluster DNS server:

```sh
kubectl -n starfleet-036-030-01-02 exec threat-client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local
```

```text
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	kubernetes.default.svc.cluster.local
Address: 10.96.0.1

```

The DNS server at `10.96.0.10` answers, so the Pod can still send traffic out. Save this as `networkpolicy-quarantine.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine
  namespace: starfleet-036-030-01-02
spec:
  podSelector:
    matchLabels:
      incident: quarantine
  policyTypes:
  - Ingress
  - Egress
```

Apply it:

```sh
kubectl apply -f networkpolicy-quarantine.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-030-01-02 get pod threat-client -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,PHASE:.status.phase,INCIDENT:.metadata.labels.incident
kubectl -n starfleet-036-030-01-02 get networkpolicy quarantine -o yaml
```

```text
NAME            UID                                    PHASE     INCIDENT
threat-client   70e39f38-591a-4a30-88a8-80860ad33d9b   Running   quarantine
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"networking.k8s.io/v1","kind":"NetworkPolicy","metadata":{"annotations":{},"name":"quarantine","namespace":"starfleet-036-030-01-02"},"spec":{"podSelector":{"matchLabels":{"incident":"quarantine"}},"policyTypes":["Ingress","Egress"]}}
  creationTimestamp: "2026-11-22T20:41:37Z"
  generation: 1
  name: quarantine
  namespace: starfleet-036-030-01-02
  resourceVersion: "604"
  uid: c4e86c81-f75b-42c2-81d2-ae7eefca4d14
spec:
  podSelector:
    matchLabels:
      incident: quarantine
  policyTypes:
  - Ingress
  - Egress
```

The Pod keeps its UID and its `Running` phase, and it now carries `incident=quarantine`. The policy has a `podSelector` and both `policyTypes`, and no `ingress` or `egress` rules. Now run the same DNS lookup from both Pods. The `probe` Pod is the control: it carries no quarantine label, so its lookup must still work:

```sh
kubectl -n starfleet-036-030-01-02 exec threat-client -- nslookup -timeout=3 kubernetes.default.svc.cluster.local
kubectl -n starfleet-036-030-01-02 exec deploy/probe -- nslookup -timeout=3 kubernetes.default.svc.cluster.local
```

```text
;; connection timed out; no servers could be reached

command terminated with exit code 1
Server:		10.96.0.10
Address:	10.96.0.10:53


Name:	kubernetes.default.svc.cluster.local
Address: 10.96.0.1

```

The lookup from `threat-client` times out, and kubectl reports exit code 1. kindnet drops the request because the policy denies all egress traffic of the Pod. The lookup from `probe` still gets an answer, so the policy selects only the labelled Pod. The policy blocks network traffic only. It does not stop a process inside the Pod, and it does not change what the ServiceAccount token may do from somewhere else.

## Find and delete the long-lived token

A ServiceAccount can have tokens that live outside any Pod. A Secret of the type `kubernetes.io/service-account-token` holds a token that the token controller in kube-controller-manager creates for the ServiceAccount named in the annotation `kubernetes.io/service-account.name`. That token has no expiry time. It works from any machine that can reach the API server, until the Secret is deleted. List the token Secrets of the namespace with the ServiceAccount each one belongs to:

```sh
kubectl -n starfleet-036-030-01-02 get secrets --field-selector type=kubernetes.io/service-account-token -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.metadata.annotations.kubernetes\\.io/service-account\\.name
```

```text
NAME                  SERVICEACCOUNT
threat-reader-token   threat-reader
```

One Secret, `threat-reader-token`, belongs to `threat-reader`. Delete it:

```sh
kubectl -n starfleet-036-030-01-02 delete secret threat-reader-token
```

When the API server authenticates a token of this kind, it checks that its Secret still exists. With the Secret gone, the API server rejects that token on the next request. The token that the kubelet projected into the `threat-client` Pod is a different token. It is bound to the Pod and stays valid while the Pod exists, so the Pod still holds a working identity. The next step removes what that identity is allowed to do.

## Remove the RoleBinding of threat-reader

A Role lists permissions inside one namespace, and a RoleBinding gives the permissions of a Role to subjects such as ServiceAccounts. Here two RoleBindings point to the same Role. List them with their subjects, and ask the API server what each identity may do:

```sh
kubectl -n starfleet-036-030-01-02 get rolebindings -o wide
kubectl -n starfleet-036-030-01-02 auth can-i get secrets --as=system:serviceaccount:starfleet-036-030-01-02:threat-reader
```

```text
NAME                    ROLE                 AGE   USERS   GROUPS   SERVICEACCOUNTS
probe-reader-secrets    Role/secret-reader   5s                     starfleet-036-030-01-02/probe-reader
threat-reader-secrets   Role/secret-reader   5s                     starfleet-036-030-01-02/threat-reader
yes
```

The API server answers `yes`, so `threat-reader` can still read Secrets. The binding `threat-reader-secrets` gives the Role `secret-reader` to `threat-reader`, and `probe-reader-secrets` gives the same Role to `probe-reader`. Deleting the Role would also remove the access of `probe-reader`, so delete only the binding of `threat-reader`:

```sh
kubectl -n starfleet-036-030-01-02 delete rolebinding threat-reader-secrets
```

The RBAC (role-based access control) authorizer in the API server checks the bindings on every request. The change takes effect on the next request, for every token of `threat-reader`, the projected token in the Pod included. Check both identities:

```sh
kubectl -n starfleet-036-030-01-02 auth can-i get secrets --as=system:serviceaccount:starfleet-036-030-01-02:threat-reader
kubectl -n starfleet-036-030-01-02 auth can-i list secrets --as=system:serviceaccount:starfleet-036-030-01-02:threat-reader
kubectl -n starfleet-036-030-01-02 auth can-i get secrets --as=system:serviceaccount:starfleet-036-030-01-02:probe-reader
kubectl -n starfleet-036-030-01-02 get secrets --field-selector type=kubernetes.io/service-account-token
```

```text
no
no
yes
No resources found in starfleet-036-030-01-02 namespace.
```

The API server answers `no` for `threat-reader` and `yes` for `probe-reader`, and no token Secret remains in the namespace. The `--as` flag asks the API server to evaluate the request as the named ServiceAccount. Your own identity needs the `impersonate` permission for that. The administrator user in the kind kubeconfig has it.

The Pod is now marked, cut off from the network and left with an identity that cannot read Secrets, and the evidence is still in place. One question stays open: what the attacker already read. A Secret read that succeeded earlier cannot be undone, so the values in `probe-settings` must be rotated, and the incident team decides when the Pod may finally be deleted.

When you are done, remove the lab with `astrona destroy ats-036-lab-030-01-02`.

## Common pitfalls

> [!WARNING]
> - **Deleting the Pod to contain it.** The container state and logs go with it, and the token Secret and the RoleBinding stay.
> - **Deleting the Role instead of the binding.** The Role `secret-reader` also serves `probe-reader`, so deleting it breaks the legitimate workload.
> - **Trusting the label alone.** A label blocks no traffic. The NetworkPolicy does, through the network plugin.
> - **A selector that is too wide.** An empty `podSelector` (`{}`) selects every Pod of the namespace and cuts the `probe` traffic too.
> - **Forgetting the projected token.** Deleting the token Secret does not invalidate the token inside the running Pod. Only removing the binding takes away what that token can do.
