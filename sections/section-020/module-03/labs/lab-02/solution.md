---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Move A Secret From An Environment Variable To A Read-Only Volume Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A Secret is a Kubernetes object that holds a small amount of sensitive data, such as a password, as base64-encoded values. A Pod can receive a Secret value in two ways. The kubelet can put it into an environment variable of the container, or it can write it as a file into a secret volume. An environment variable is visible to every process in the container, is copied to child processes, and often ends up in crash reports and debug output. A file in a secret volume has file permissions you can restrict, and the program reads it only when it needs it. This task first records which workloads use each path, then moves one Deployment to the file path.

## Find the workloads that read the Secret

Start with the Pods. The `custom-columns` output prints one row per Pod, with the Secrets each Pod reads through `env` and the Secrets it mounts as volumes:

```sh
kubectl -n starfleet-036-020-03-02 get pods -o custom-columns='NAME:.metadata.name,SECRETENV:.spec.containers[*].env[*].valueFrom.secretKeyRef.name,SECRETVOL:.spec.volumes[*].secret.secretName'
```

<!-- CAPTURE: l2-pod-columns -->

Three Pods use a Secret. The `billing-...` Pod reads `db-credentials` through an environment variable. Pod `reports` mounts `db-credentials` as a volume. Pod `ledger` reads a different Secret, `ledger-token`, so it does not belong in this report. The Pod name `billing-...` has a random suffix because a Deployment created it. Record the Deployment, because the Deployment holds the Pod template, and a new Pod from the same template would read the Secret in the same way. Check the Deployment with the same columns, this time under `.spec.template`:

```sh
kubectl -n starfleet-036-020-03-02 get deployments -o custom-columns='NAME:.metadata.name,SECRETENV:.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name,SECRETVOL:.spec.template.spec.volumes[*].secret.secretName'
```

<!-- CAPTURE: l2-deployment-columns -->

The `billing` Deployment shows `db-credentials` in the `SECRETENV` column. These columns show only `env` entries with `secretKeyRef`. A container can also load every key of a Secret at once with `envFrom` and `secretRef`, so check `.spec.containers[*].envFrom` as well in a real review. No workload in this lab uses `envFrom`.

## Record the exposure

Write the result into a ConfigMap, a Kubernetes object that stores key and value pairs as strings. Name each workload as `<kind>/<name>`, the same form kubectl uses. Save this as `configmap-secret-exposure.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-exposure
  namespace: starfleet-036-020-03-02
data:
  secret: db-credentials
  envWorkload: deployment/billing
  volumeWorkload: pod/reports
```

Apply it:

```sh
kubectl apply -f configmap-secret-exposure.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-020-03-02 get configmap secret-exposure -o jsonpath='{.data}{"\n"}'
```

<!-- CAPTURE: l2-report -->

The report names the Secret and both paths, and it does not contain the Secret value. Before you change `billing`, see the problem for yourself. Ask the running container for the variable:

```sh
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- printenv DB_PASSWORD
```

<!-- CAPTURE: l2-printenv-before -->

The container prints the password in clear text. The kubelet decoded the base64 value when it started the container and placed the result in the environment. Every process in the container, and every crash report that dumps the environment, can see it.

## Mount the Secret as a read-only volume

The environment of a running container cannot change. To remove the variable, change the Pod template of the Deployment. The Deployment controller then creates a new ReplicaSet, which starts a new Pod and stops the old one. The new template removes `DB_PASSWORD`, keeps `DB_HOST`, and adds a secret volume. The field `defaultMode: 0400` sets the file permissions to read for the file owner only. The leading zero matters, because YAML reads `0400` as an octal number. The field `readOnly: true` on the volume mount stops the container from writing to the mounted directory.

Save this as `deployment-billing.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: starfleet-036-020-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: billing
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - exec sleep 86400
        env:
        - name: DB_HOST
          value: db.starfleet-036-020-03-02.svc.cluster.local
        volumeMounts:
        - name: db-credentials
          mountPath: /etc/db
          readOnly: true
      volumes:
      - name: db-credentials
        secret:
          secretName: db-credentials
          defaultMode: 0400
```

Apply it:

```sh
kubectl apply -f deployment-billing.yaml
```

Then check the result. `kubectl rollout status` waits until the new Pod is ready and the old one is gone, with a time limit:

```sh
kubectl -n starfleet-036-020-03-02 rollout status deployment/billing --timeout=120s
```

<!-- CAPTURE: l2-rollout -->

`kubectl apply` removed the `DB_PASSWORD` entry because the earlier version of the Deployment was also created with `kubectl apply`, so kubectl knows which fields it set before. If you edit the Deployment with `kubectl edit` instead, delete the entry by hand.

## Verify the new Pod

Check the three facts the task asks for: the file exists with the right mode, the program can read it, and the variable is gone. The option `-L` of `ls` follows links. The kubelet writes the Secret files into a hidden directory and links each key name to them, so without `-L` you see the link and not the file mode:

```sh
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- ls -lL /etc/db
```

<!-- CAPTURE: l2-ls -->

The file `password` has the mode `-r--------`, which is 0400. Now read the file, as the program would. The `echo` adds a line break, because the Secret value has none:

```sh
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- cat /etc/db/password; echo
```

<!-- CAPTURE: l2-cat -->

The file holds the same password the variable held before. Finally, ask for the variable again:

```sh
kubectl -n starfleet-036-020-03-02 exec deploy/billing -- printenv DB_PASSWORD; echo "exit code $?"
```

<!-- CAPTURE: l2-printenv-after -->

`printenv` prints nothing and exits with a non-zero code, because the new container has no `DB_PASSWORD`. A crash report that dumps the environment no longer contains the password.

You now know how to find the two ways a workload reads a Secret, and how to move a Deployment from an environment variable to a read-only file with restricted permissions. The open question is who can still reach the file. A user with the right to run `kubectl exec` in the Pod can still read `/etc/db/password`, as the check above shows, so the `pods/exec` permission in RBAC (role-based access control) is still part of the protection. After recording the result, remove this lab with `astrona destroy ats-036-lab-020-03-02`.

## Common pitfalls

> [!WARNING]
> - **Reporting the Pod instead of the Deployment.** A Pod created by a Deployment is replaced on the next rollout. The template in the Deployment is what reads the Secret.
> - **Checking only `env`.** A container can load a whole Secret with `envFrom` and `secretRef`. Look at both fields.
> - **Writing `defaultMode: 400`.** Without the leading zero, YAML reads a decimal number, which is a different mode. Write `0400` or the decimal value `256`.
> - **Running `ls -l` without `-L`.** The key names in a secret volume are links, and `ls -l` shows the mode of the link.
> - **Checking the old Pod.** Wait for `kubectl rollout status` before you test, or `kubectl exec` can still reach the Pod that has the variable.
> - **Treating the volume as full protection.** Anyone who can run `kubectl exec` in the Pod can still read the file.
