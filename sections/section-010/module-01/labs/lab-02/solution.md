---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Quarantine A Suspicious Pod Without Deleting It Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Read the alert

An alert is only useful when it names one object. The ConfigMap `shell-alert` holds the name and the UID of the Pod where the shell started. A UID is the unique identifier that the API server gives an object when it creates it. A new Pod with the same name gets a new UID, so the UID tells you whether you still look at the same Pod. Read the alert and keep the Pod name in a shell variable:

```sh
kubectl -n starfleet-036-010-01-02 get configmap shell-alert -o jsonpath='{.data}{"\n"}'
suspect_pod="$(kubectl -n starfleet-036-010-01-02 get configmap shell-alert -o jsonpath='{.data.pod}')"
kubectl -n starfleet-036-010-01-02 get pods -L app,release
```

The output shows the alert and the two `probe` Pods:

```text
{"container":"probe","pod":"probe-7db6ffd7d6-9g79s","rule":"Shell started in probe container","uid":"495a8804-08c2-41d7-a4d4-11021a2eb03d"}
NAME                     READY   STATUS    RESTARTS   AGE   APP       RELEASE
probe-7db6ffd7d6-9g79s   1/1     Running   0          3s    probe     probe
probe-7db6ffd7d6-wb9nz   1/1     Running   0          3s    probe     probe
shuttle                  1/1     Running   0          3s    shuttle   
```

The Pod names and the UID are different in your cluster. The `shuttle` Pod is a client in the same namespace. Both `probe` Pods carry `app=probe` and `release=probe`, so the Deployment counts both and the Service sends requests to both.

## Capture evidence before you change anything

Some evidence exists only while the container runs: the process list, open connections and files in `/tmp`. Capture it first, because every later step can change it. An ephemeral container is a temporary container that you add to a running Pod for debugging. The kubelet starts it next to the existing containers, and it stays in the Pod specification until the Pod is deleted. With `--target=probe`, kubectl asks the container runtime to put the new container in the process namespace of the `probe` container, so `ps` shows the processes of `probe`:

```sh
kubectl -n starfleet-036-010-01-02 debug "$suspect_pod" --image=docker.io/library/busybox:1.37.0 --target=probe --container=evidence -- sh -c 'ps; ls -l /proc/1/root/tmp'
```

kubectl prints a short notice and returns:

```text
Targeting container "probe". If you don't see processes from this container it may be because the container runtime doesn't support this feature.
```

The command does not wait for the container. Wait a few seconds, then read the log of the `evidence` container:

```sh
kubectl -n starfleet-036-010-01-02 logs "$suspect_pod" -c evidence
```

```text
PID   USER     TIME  COMMAND
    1 root      0:00 python /app/server.py
   20 root      0:00 sh -c ps; ls -l /proc/1/root/tmp
   33 root      0:00 ps
total 4
-rw-r--r--    1 root     root             7 Nov 22 20:41 dropped-tool
```

Process 1 is the Python web server of the `probe` container. The listing of `/proc/1/root/tmp` shows the file system of that container as the server sees it, including the file that the shell wrote. Save this output with the alert before you go on.

## Quarantine the Pod

A Deployment and a Service find their Pods through a label selector. A label selector is a list of labels that a Pod must carry to match. When you remove a selected label from a Pod, the Pod leaves both selections at once. The ReplicaSet of the Deployment then sees only one matching Pod, so it removes its owner reference from the old Pod and creates a new Pod from the template. The old Pod keeps running, with the same UID. Remove the two labels and add the quarantine label in one command:

```sh
kubectl -n starfleet-036-010-01-02 label pod "$suspect_pod" app- release- quarantine=true
kubectl -n starfleet-036-010-01-02 rollout status deployment/probe --timeout=120s
```

A label name with a minus sign at the end removes that label. The output confirms the change and the rollout:

```text
pod/probe-7db6ffd7d6-9g79s modified
Waiting for deployment "probe" rollout to finish: 1 of 2 updated replicas are available...
deployment "probe" successfully rolled out
```

## Check the result

Check three things: the suspect Pod still runs, the Deployment has two new or old Pods with both labels, and the Service no longer lists the suspect Pod. An EndpointSlice is the object in which the EndpointSlice controller lists the Pod addresses of a Service:

```sh
kubectl -n starfleet-036-010-01-02 get pods -L app,release,quarantine -o wide
kubectl -n starfleet-036-010-01-02 get endpointslices -l kubernetes.io/service-name=probe
```

```text
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE                                             NOMINATED NODE   READINESS GATES   APP       RELEASE   QUARANTINE
probe-7db6ffd7d6-9g79s   1/1     Running   0          18s   10.244.0.5   astro-test-ats-036-lab-010-01-02-control-plane   <none>           <none>                                true
probe-7db6ffd7d6-dk5jh   1/1     Running   0          7s    10.244.0.9   astro-test-ats-036-lab-010-01-02-control-plane   <none>           <none>            probe     probe     
probe-7db6ffd7d6-wb9nz   1/1     Running   0          18s   10.244.0.6   astro-test-ats-036-lab-010-01-02-control-plane   <none>           <none>            probe     probe     
shuttle                  1/1     Running   0          18s   10.244.0.7   astro-test-ats-036-lab-010-01-02-control-plane   <none>           <none>            shuttle             
NAME          ADDRESSTYPE   PORTS   ENDPOINTS               AGE
probe-4xks9   IPv4          8080    10.244.0.6,10.244.0.9   18s
```

Three `probe` Pods run next to `shuttle`. The output comes from a test cluster, so the node name starts with `astro-test-ats-036-lab-...`; in your lab it starts with `astro-ats-036-lab-...`, and the Pod names and IP addresses differ. The suspect Pod has `quarantine=true` and no `app` or `release` label, and its IP address is not in the EndpointSlice. The Service now sends requests only to the two Pods that carry both labels. The quarantine stops traffic but does not remove the cause. The new Pod uses the same template and the same ServiceAccount, so a compromised image or token stays a risk until you fix them. When the analysis is done, delete the quarantined Pod.

After recording the result, remove this independent lab with `astrona destroy ats-036-lab-010-01-02`.

## Common pitfalls

> [!WARNING]
> - **Deleting the Pod first.** The process list, the open connections and the files in `/tmp` are gone, and the ReplicaSet creates a new Pod with a new UID.
> - **Changing only one of the two labels.** The Service and the Deployment select `app=probe` and `release=probe`. A Pod that keeps one of them can still match a selector that uses only that label.
> - **Running the evidence container without `--target`.** Without a shared process namespace, `ps` lists only the processes of the ephemeral container itself.
> - **Expecting to remove the ephemeral container.** It stays in the Pod specification until the Pod is deleted. Use a clear name such as `evidence`.
