---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Link An Exec Audit Record To Its Node And Container Solution

An audit record tells you that an identity asked the API server to run a command in a Pod. It does not tell you where that command ran. A runtime sensor, a node log or a forensic copy of a container works with nodes and container IDs, not with audit IDs. To hand the case to the runtime team, you link the record to the node that runs the Pod and to the ID of the container that received the command.

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-010-03-02" || exit 1
node_name="astro-ats-036-lab-010-03-02-control-plane"
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context. The commands below use `podman exec` to run a command inside a node container of this lab. If your lab runs on Docker, write `docker exec` instead.

## Find the exec request in the audit log

Start with the Pods, so that you know what the audit record can point to. The `-o wide` output adds the node of each Pod:

```sh
kubectl -n starfleet-036-010-03-02 get pods -l app=probe -o wide
```

<!-- CAPTURE: l1-probe-pods -->

The two `probe` Pods run on different nodes: one on the control-plane node and one on the worker. The `READY` column shows `2/2`, because each Pod has two containers. So a Pod name alone does not say which node or which container an attacker used.

The API server (`kube-apiserver`) writes one JSON line for each audit event to `/var/log/training-audit/audit.jsonl` on the control-plane node. An `exec` request is a request on the resource `pods` with the subresource `exec`. A short program can filter the log for those requests and print the fields you need.

Save this as `exec-report.py`:

```python
import json
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    reference = event.get("objectRef", {})
    if reference.get("subresource") != "exec":
        continue
    print(
        event.get("auditID"),
        event.get("stage"),
        reference.get("name"),
        event.get("requestURI"),
    )
```

Run it against the log on the control-plane node:

```sh
podman exec "$node_name" cat /var/log/training-audit/audit.jsonl | python3 exec-report.py
```

<!-- CAPTURE: l1-exec-report -->

Each line is one audit event. An `exec` request keeps a connection open, so the API server can write more than one event for it, one for each stage. All events of one request share the same `auditID`. The third column is `objectRef.name`, the Pod that received the request. The `requestURI` lists the command as `command=` parameters and the container as the `container=` parameter. Here it is `container=probe`: kubectl always sends the container name, and it asked for the `probe` container, not `log-agent`.

Put the values from your output into variables. Your audit ID and Pod name are different from any example:

```sh
audit_id="<AUDIT_ID>"
pod_name="<POD_NAME>"
```

## Find the node and the container ID

The audit record does not hold the node. The scheduler wrote the node into the Pod's `spec.nodeName` when it placed the Pod, and that field does not change while the Pod lives. Read it:

```sh
kubectl -n starfleet-036-010-03-02 get pod "$pod_name" -o jsonpath='{.spec.nodeName}{"\n"}'
```

<!-- CAPTURE: l1-node-name -->

The Pod that received the `exec` request runs on the control-plane node. Compare this with the `get pods -o wide` output: it is one of the two nodes, and only the audit record tells you which Pod, and so which node, is the right one.

The kubelet, the node agent that starts the containers of a Pod, reports the ID of each container in `.status.containerStatuses`. The ID comes from the container runtime, containerd in this cluster, so it starts with `containerd://`. This Pod has two containers, so print every entry with its name instead of taking the first one:

```sh
kubectl -n starfleet-036-010-03-02 get pod "$pod_name" -o jsonpath='{range .status.containerStatuses[*]}{.name}{" "}{.containerID}{"\n"}{end}'
```

<!-- CAPTURE: l1-container-ids -->

The output has one line for `log-agent` and one for `probe`. The `exec` request named `probe`, so its line holds the container ID you need. The `log-agent` ID belongs to a different process and would send the runtime team to the wrong container. Put the `probe` value into a variable:

```sh
container_id="$(kubectl -n starfleet-036-010-03-02 get pod "$pod_name" -o jsonpath='{.status.containerStatuses[?(@.name=="probe")].containerID}')"
pod_node="$(kubectl -n starfleet-036-010-03-02 get pod "$pod_name" -o jsonpath='{.spec.nodeName}')"
```

You can confirm the ID on the node itself. In a kind cluster each node is a container with the same name as the node, and `crictl` is the command-line client of the container runtime inside it. `crictl` uses the ID without the `containerd://` prefix:

```sh
podman exec "$pod_node" crictl ps --id "${container_id#containerd://}"
```

<!-- CAPTURE: l1-crictl-ps -->

Check the `STATE` and `NAME` columns: containerd on that node runs the container with this ID, and its name is `probe`. This is the view that a runtime sensor on the node has, and the container ID is the value that links it to the audit record.

## Record the correlation

Write the five values into a ConfigMap. Keep the `containerID` exactly as the Pod status shows it, with the `containerd://` prefix. Get each value with `echo`, for example `echo $audit_id`, `echo $pod_node` and `echo $container_id`.

Save this as `configmap-exec-correlation.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: exec-correlation
  namespace: starfleet-036-010-03-02
data:
  auditID: <AUDIT_ID>
  podName: <POD_NAME>
  container: probe
  nodeName: <NODE_NAME>
  containerID: <CONTAINER_ID>
```

Apply it:

```sh
kubectl apply -f configmap-exec-correlation.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-010-03-02 get configmap exec-correlation -o yaml
```

<!-- CAPTURE: l1-configmap -->

The ConfigMap now links three sources. The `auditID` points to the record that the API server wrote. The `podName` and `container` come from that record. The `nodeName` and `containerID` come from the Pod object, which the scheduler and the kubelet filled in. A runtime alert or a node log that holds the same container ID, at a time close to the audit record's `stageTimestamp`, belongs to the same session.

The correlation is only valid while the container lives. When the container restarts, the kubelet starts a new container with a new ID, and the audit record still points to the old Pod name. Read the Pod status early, and copy it before anyone restarts or deletes the Pod.

When you are done, remove the lab with `astrona destroy ats-036-lab-010-03-02`.

## Common pitfalls

> [!WARNING]
> - **Taking the first entry of `containerStatuses`.** A Pod can have several containers. Select the entry whose `name` matches the `container=` parameter of the request.
> - **Dropping the `containerd://` prefix in the report.** The Pod status keeps the prefix. Only `crictl` takes the ID without it.
> - **Guessing the node from the Pod list.** The `probe` replicas run on different nodes. Use the Pod named in `objectRef.name` and read its `spec.nodeName`.
> - **Restarting the Pod to inspect it.** A restart creates a new container ID, and the link to the session is lost.
