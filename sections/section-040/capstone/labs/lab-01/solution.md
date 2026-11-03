---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Harden A Workload And Enforce A Read-Only Root Filesystem Policy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-capstone-040" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

The `probe` Deployment in `starfleet` runs as root with default capabilities and a writable root filesystem. Complete the required change without replacing unrelated resources.

Inspect the relevant evidence:

```sh
kubectl -n starfleet get deployment probe -o yaml
kubectl -n starfleet get pods -l app=probe
kubectl get validatingadmissionpolicy
```

Two controls work together. The Pod template makes the running containers immutable and unprivileged. The admission rule stops a new mutable Pod from being created. A ValidatingAdmissionPolicy needs a policy and a binding, and the binding chooses the action and the namespaces. A server-side dry run tests the rule without creating a Pod.

Save this as `deployment-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
      release: probe
  template:
    metadata:
      labels:
        app: probe
        release: probe
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v1
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 2
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 128Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: app
        configMap:
          name: probe-code
      - name: tmp
        emptyDir: {}
```

Save this as `validatingadmissionpolicy-require-read-only-root.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-read-only-root
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups:
      - ""
      apiVersions:
      - v1
      operations:
      - CREATE
      resources:
      - pods
  validations:
  - expression: "object.spec.containers.all(c, has(c.securityContext) && has(c.securityContext.readOnlyRootFilesystem) && c.securityContext.readOnlyRootFilesystem)"
    message: "Every container must set readOnlyRootFilesystem to true."
```

Save this as `validatingadmissionpolicybinding-require-read-only-root.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-read-only-root
spec:
  policyName: require-read-only-root
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: starfleet
```

Apply the required change:

```sh
kubectl apply -f deployment-probe.yaml
kubectl apply -f validatingadmissionpolicy-require-read-only-root.yaml
kubectl apply -f validatingadmissionpolicybinding-require-read-only-root.yaml
```

## Verify The Result

Observe the actual result. A denied-request command returns a nonzero status when the denial works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe/ready
kubectl -n starfleet exec deploy/probe -- id -u
kubectl -n starfleet run mutable-check --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -o name
kubectl -n outpost run outside-check --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -o name
```

Harden Deployment `probe` in `starfleet` through its Pod template, and keep `VERSION` at `v1`. The Pod must run as user and group 10001 with `runAsNonRoot: true` and RuntimeDefault seccomp. The `probe` container must have a read-only root filesystem, disable privilege escalation and drop all capabilities. Keep the existing `app` volume and its read-only mount first, then add an `emptyDir` volume named `tmp` mounted at `/tmp`. Then create ValidatingAdmissionPolicy `require-read-only-root` and ValidatingAdmissionPolicyBinding `require-read-only-root`. The policy must reject `CREATE` of Pods whose containers do not set `readOnlyRootFilesystem` to true. The binding must use the `Deny` action and apply only to the `starfleet` namespace. The service must keep answering with `version=v1`. A new Pod with a writable root filesystem must be rejected in `starfleet` and accepted in `outpost`.

After recording the result, remove this independent lab with `astrona destroy ats-036-capstone-040`.

## Common pitfalls

> [!WARNING]
> The rule applies to new Pods only, so the Deployment must already create compliant Pods. A binding without `Deny` does not block anything. Test the rule with a server-side dry run in both namespaces.
