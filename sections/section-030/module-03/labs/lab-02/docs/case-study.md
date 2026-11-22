---
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Starting Environment

The `probe`, `shuttle` and `memory-hog` containers have CPU and memory limits. The `worker` container of the `cruncher` Deployment has no requests and no limits. The `memory-hog` container writes more memory than its 32 MiB limit allows, so the kernel kills it and the kubelet restarts it.

Record `unlimitedWorkload: cruncher` and `oomKilledPod: memory-hog` in the ConfigMap `impact-report`. Set requests and limits on `cruncher`, and add the LimitRange `container-limits` so that new containers without resources get default limits.
