---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Guided Practice: Update A Workload By Replacement With A Read-Only Root

Use a host shell with this environment's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the graded labs.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-playground-040-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

The `probe` Deployment runs version `v1` with a writable root filesystem. Complete the required change without replacing unrelated resources.

Inspect the relevant evidence:

```sh
kubectl -n starfleet get deployment probe -o yaml
kubectl -n starfleet get pods -l app=probe
```

A change to the Pod template makes the Deployment controller create a new ReplicaSet and replace the Pods. The application writes marker files under `/tmp`, so a read-only root filesystem needs a writable `emptyDir` volume there. Wait for the rollout before you verify.

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
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v2
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

Apply the required change:

```sh
kubectl apply -f deployment-probe.yaml
```

## Verify The Result

Observe the actual result. A denied-request command returns a nonzero status when the denial works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe/ready
kubectl -n starfleet exec deploy/probe -- sh -c 'printf ok > /tmp/scratch-check; cat /tmp/scratch-check'
kubectl -n starfleet exec deploy/probe -- sh -c 'printf denied > /root-file'
```

Change Deployment `probe` in `starfleet` through its Pod template. Set the `VERSION` environment variable to `v2`. Set `readOnlyRootFilesystem: true` on the `probe` container. Keep the existing `app` volume and its read-only mount first, then add an `emptyDir` volume named `tmp` mounted at `/tmp`. Do not use a `hostPath` volume. The rollout must finish with two ready replicas, the service must answer with `version=v2`, writing to `/tmp` must work, and writing `/root-file` must fail.

## Common pitfalls

> [!WARNING]
> A read-only root filesystem without a writable `/tmp` can break the application and its readiness probe. Change the template, wait for the rollout and verify both the allowed and the denied write. Do not edit a running Pod.
