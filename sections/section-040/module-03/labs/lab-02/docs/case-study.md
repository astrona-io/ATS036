---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The namespace `starfleet-036-040-03-02` runs three Deployments with one replica each. The `collector` and `relay` Deployments mount the node directory `/var/lib/training-036-040-03-02` at `/host-data` through a volume of type `hostPath`. A `hostPath` volume mounts a file or directory of the node into the container, so the container reads and writes real node files. The `beacon` Deployment uses only an `emptyDir` volume, which the kubelet creates for the Pod and deletes with it.

The directory on the node holds `approved.txt` with the line `approved-settings-v1`. The workloads read this file. One of the two `hostPath` mounts has `readOnly: true` on its `volumeMount`; the other does not, so that container can write into the node directory. The read-only root filesystem setting of a container does not cover volumes, so each writable volume needs its own decision.

The finding goes into the ConfigMap `hostpath-finding` with the keys `workload`, `volume` and `path`. The fix changes the Pod template of the Deployment, so the Deployment controller replaces the Pod. The fixed Pod must still read `approved.txt`, and a write to `/host-data` must fail with `Read-only file system`.
