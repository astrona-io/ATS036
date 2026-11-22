---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Find A Pod's Log Files On Its Node Solution

`kubectl logs` is only a view. The real container log is a set of files on the node that runs the Pod. When the API server is not reachable, when a log collector failed to ship the lines, or when you need a copy for an investigation, you read those files on the node. This walkthrough finds them for the `crash-report` Pod and reads the file of the instance that crashed.

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context. The commands below use `podman exec` to run a command inside a node container of this lab. If your lab runs on Docker, write `docker exec` instead.

## Find the node and the Pod UID

The log files sit on one node only, so first find which node runs the Pod. The `-o wide` output adds the node:

```sh
kubectl -n starfleet-036-020-01-02 get pod crash-report -o wide
```

<!-- CAPTURE: l2-pod-wide -->

The `RESTARTS` column shows `1`: the first instance exited, and the kubelet started a second one. The `NODE` column names the node. In a kind cluster each node is a container with the same name as the node, so this name is also the container you run commands in.

The log directory on the node carries the Pod UID, not only the Pod name. The UID is the unique ID that the API server gives a Pod when it creates it. Two Pods with the same name in different namespaces, or a Pod that was deleted and created again, have different UIDs. Put the node and the UID into variables and print them:

```sh
pod_node="$(kubectl -n starfleet-036-020-01-02 get pod crash-report -o jsonpath='{.spec.nodeName}')"
pod_uid="$(kubectl -n starfleet-036-020-01-02 get pod crash-report -o jsonpath='{.metadata.uid}')"
echo "$pod_node $pod_uid"
```

<!-- CAPTURE: l2-node-uid -->

## Read the log directory on the node

The kubelet, the node agent that starts Pods, creates one directory for each Pod under `/var/log/pods`. The directory name has the form `<namespace>_<pod>_<uid>`. List the directories on the node:

```sh
podman exec "$pod_node" ls /var/log/pods
```

<!-- CAPTURE: l2-pods-directory -->

There are two directories that contain `crash-report`. One starts with `outpost-036-020-01-02_` and belongs to the other Pod with the same name. The one you need starts with `starfleet-036-020-01-02_crash-report_` and ends with the UID you printed. This is why the UID matters: the Pod name alone points to two directories.

Inside the Pod directory, the kubelet creates one directory for each container, named after the container. In it, each container instance has its own file. The file name is the restart count of that instance: `0.log` for the first instance, `1.log` after the first restart. List the files of container `report`:

```sh
log_directory="/var/log/pods/starfleet-036-020-01-02_crash-report_${pod_uid}"
podman exec "$pod_node" ls -l "$log_directory/report"
```

<!-- CAPTURE: l2-report-files -->

There are two files, `0.log` and `1.log`. The kubelet chose these paths and passed each one to the container runtime, containerd, when it created the container. containerd then wrote the standard output and standard error of the container into the file. The second instance is still running, so containerd still writes to `1.log`.

## Read the file of the crashed instance

The crashed instance is the first one, so its file is `0.log`. Read it on the node:

```sh
podman exec "$pod_node" cat "$log_directory/report/0.log"
```

<!-- CAPTURE: l2-previous-file -->

Each line has the format that the container runtime uses for log files. It starts with the time in RFC 3339 format (a standard date and time format) with nanoseconds, then the stream, `stdout` or `stderr`, then the tag `F` for a full line or `P` for a part of a longer line, and then the text that the container printed. `kubectl logs` removes these three fields before it shows you the text. The line with `crash-token=` exists only in this file, because only the first instance printed it.

The kubelet also keeps a second path to the same files. `/var/log/containers` holds one symbolic link for each container on the node, and many log collectors read from there:

```sh
podman exec "$pod_node" ls -l /var/log/containers | grep crash-report
```

<!-- CAPTURE: l2-container-links -->

Each link name holds the Pod name, the namespace, the container name and the container ID, and each link points to a file under `/var/log/pods`. The link is a pointer only; the data lives in the Pod directory.

## Record the evidence

Write the values into a ConfigMap. Get each value with `echo`: `echo $pod_node`, `echo $pod_uid` and `echo $log_directory`. The token is the text after `crash-token=` in `0.log`, without the prefix.

Save this as `configmap-node-log-evidence.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-log-evidence
  namespace: starfleet-036-020-01-02
data:
  nodeName: <NODE_NAME>
  podUID: <POD_UID>
  logDirectory: /var/log/pods/starfleet-036-020-01-02_crash-report_<POD_UID>
  logFiles: 0.log,1.log
  crashToken: <CRASH_TOKEN>
```

Apply it:

```sh
kubectl apply -f configmap-node-log-evidence.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-020-01-02 get configmap node-log-evidence -o yaml
```

<!-- CAPTURE: l2-configmap -->

The ConfigMap now holds a path that someone else can open on the node, and a value that only the crashed instance wrote. The files stay on the node only while the Pod exists. When the Pod is deleted or evicted, the kubelet removes its directory under `/var/log/pods`. When a file reaches `containerLogMaxSize` (10Mi by default), the kubelet rotates it and keeps at most `containerLogMaxFiles` (5 by default) files per container. An attacker with access to the node can also change or delete these files. Copy them, or ship them to a store outside the node, as soon as they matter.

When you are done, remove the lab with `astrona destroy ats-036-lab-020-01-02`.

## Common pitfalls

> [!WARNING]
> - **Matching the directory by Pod name only.** Pods with the same name in other namespaces, or an older Pod with the same name, have their own directories. Match the namespace and the UID.
> - **Looking on the wrong node.** The files exist only on the node in the Pod's `spec.nodeName`.
> - **Reading the newest file for the crash.** The highest number is the running instance. The crashed instance is the file before it.
> - **Deleting the Pod to see a clean start.** The kubelet removes the Pod's log directory with the Pod, and the evidence is gone.
