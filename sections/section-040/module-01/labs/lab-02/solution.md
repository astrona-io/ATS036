---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Enforce A Read-Only Root Filesystem With A ValidatingAdmissionPolicy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-040-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The setting `readOnlyRootFilesystem: true` protects only the Pod that sets it. To make it a rule for a namespace, the API server must check every new Pod before it stores it. A ValidatingAdmissionPolicy is a built-in admission rule for this job. It holds an expression in the Common Expression Language (CEL), and the API server evaluates the expression for each matching request. When the expression is false, the API server rejects the request. No webhook server is involved.

Start with the current state. List the Pods of `starfleet-036-040-01-02` with the value of the field for each container:

```sh
kubectl -n starfleet-036-040-01-02 get pods -o custom-columns='NAME:.metadata.name,READONLY:.spec.containers[*].securityContext.readOnlyRootFilesystem'
```

```text
NAME                     READONLY
probe-7db6ffd7d6-clmrg   <none>
probe-7db6ffd7d6-rntp4   <none>
shuttle                  <none>
```

The random suffixes of the `probe` Pod names differ in your lab. No Pod sets the field, so every root filesystem is writable. These Pods were admitted before any policy existed. Admission runs only when a request arrives, so the policy you create below does not stop them.

## Select the namespace with a label

A ValidatingAdmissionPolicyBinding decides where a policy applies. A `namespaceSelector` in the binding picks namespaces by their labels, so a label on the namespace is the switch. Add the label to `starfleet-036-040-01-02` only:

```sh
kubectl label namespace starfleet-036-040-01-02 immutability=enforced
```

```text
namespace/starfleet-036-040-01-02 labeled
```

Then check which namespaces carry the label:

```sh
kubectl get namespaces -l immutability=enforced
```

```text
NAME                      STATUS   AGE
starfleet-036-040-01-02   Active   3s
```

Only `starfleet-036-040-01-02` is listed. The namespace `outpost-036-040-01-02` has no such label, so a binding that selects the label never reaches it.

## Create the policy

The policy holds the rule and says which requests it looks at. The `matchConstraints` section limits it to `CREATE` and `UPDATE` requests for `pods` in the core API group. The expression uses `all()` to test every container, not only the first one. It uses `has()` before each field, because reading a field that is not set is an error in CEL, and with `failurePolicy: Fail` an error also rejects the request, but with a confusing message.

Save this as `validatingadmissionpolicy-require-read-only-root.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-read-only-root-036-040-01-02
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "object.spec.containers.all(c, has(c.securityContext) && has(c.securityContext.readOnlyRootFilesystem) && c.securityContext.readOnlyRootFilesystem)"
    message: "Every container must set readOnlyRootFilesystem to true."
```

Apply it:

```sh
kubectl apply -f validatingadmissionpolicy-require-read-only-root.yaml
```

```text
validatingadmissionpolicy.admissionregistration.k8s.io/require-read-only-root-036-040-01-02 created
```

A policy on its own does nothing. The API server evaluates it only for requests that a binding selects.

## Bind the policy to the labelled namespace

The binding names the policy, selects the namespaces and sets `validationActions`. The value `Deny` makes the API server reject a request that fails the expression. The other values, `Warn` and `Audit`, let the request through and only return a warning or add an audit annotation.

Save this as `validatingadmissionpolicybinding-require-read-only-root.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-read-only-root-starfleet-036-040-01-02
spec:
  policyName: require-read-only-root-036-040-01-02
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        immutability: enforced
```

Apply it:

```sh
kubectl apply -f validatingadmissionpolicybinding-require-read-only-root.yaml
```

```text
validatingadmissionpolicybinding.admissionregistration.k8s.io/require-read-only-root-starfleet-036-040-01-02 created
```

The API server needs a few seconds to load a new binding. If the first test below is accepted, wait a few seconds and run it again.

## Test the policy with server-side dry runs

A server-side dry run sends the object through every admission step of the API server, but the API server does not store it. This is the safe way to test a policy: no Pod starts, and nothing needs cleaning up. The test Pods below have no `namespace` field, so you can send the same file to both namespaces with `-n`.

Save this as `pod-writable-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: writable-check
spec:
  restartPolicy: Never
  containers:
  - name: main
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Send it to the labelled namespace:

```sh
kubectl -n starfleet-036-040-01-02 create --dry-run=server -f pod-writable-check.yaml
```

```text
The pods "writable-check" is invalid: : ValidatingAdmissionPolicy 'require-read-only-root-036-040-01-02' with binding 'require-read-only-root-starfleet-036-040-01-02' denied request: Every container must set readOnlyRootFilesystem to true.
```

The API server rejects the Pod. The error names the policy and the binding, and it shows the message from the policy. The ValidatingAdmissionPolicy admission plugin in the API server did this work, before the Pod reached storage or the scheduler.

Now send a Pod with two containers that both set the field. Save this as `pod-read-only-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: read-only-check
spec:
  restartPolicy: Never
  containers:
  - name: main
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
  - name: sidecar
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
```

Send it to the same namespace:

```sh
kubectl -n starfleet-036-040-01-02 create --dry-run=server -f pod-read-only-check.yaml
```

```text
pod/read-only-check created (server dry run)
```

The API server accepts the Pod, because the expression is true for both containers. If you remove `readOnlyRootFilesystem: true` from the `sidecar` container only, the Pod is rejected again, because `all()` checks every container.

Last, send the writable Pod to the namespace without the label:

```sh
kubectl -n outpost-036-040-01-02 create --dry-run=server -f pod-writable-check.yaml
```

```text
pod/writable-check created (server dry run)
```

The API server accepts it. The binding does not select `outpost-036-040-01-02`, so the API server never evaluates the policy for this request.

## Check the running workloads

The running Pods must keep running. List them again:

```sh
kubectl -n starfleet-036-040-01-02 get pods
```

```text
NAME                     READY   STATUS    RESTARTS   AGE
probe-7db6ffd7d6-clmrg   1/1     Running   0          14s
probe-7db6ffd7d6-rntp4   1/1     Running   0          14s
shuttle                  1/1     Running   0          14s
```

The `probe` and `shuttle` Pods are still `Running`. The policy acts only on new `CREATE` and `UPDATE` requests. It has one limit you must know: if a `probe` Pod is deleted, the ReplicaSet controller sends a `CREATE` request for a new Pod, and the API server rejects that request too. The Deployment then has fewer ready replicas until its Pod template sets `readOnlyRootFilesystem: true`. Fix the templates of existing workloads before you switch a busy namespace to `Deny`.

You now have a namespace where the API server rejects every new Pod with a writable root filesystem, and a second namespace that is not affected. The policy covers `spec.containers`; init containers and ephemeral containers are not checked by this expression.

When you are done, remove the lab with `astrona destroy ats-036-lab-040-01-02`.

## Common pitfalls

> [!WARNING]
> - **Forgetting the binding.** A ValidatingAdmissionPolicy without a ValidatingAdmissionPolicyBinding rejects nothing.
> - **Using `Warn` or `Audit` instead of `Deny`.** Both let the Pod through. Only `Deny` rejects it.
> - **Checking only the first container.** `object.spec.containers[0]` misses sidecars. Use `all()`.
> - **Reading a field without `has()`.** A missing `securityContext` makes the expression fail with an evaluation error instead of your message.
> - **Testing too early.** The API server needs a few seconds to load a new binding. Repeat the dry run before you change the policy.
> - **Restarting workloads after you enforce the rule.** New Pods from an old template are rejected. Fix the template first.
