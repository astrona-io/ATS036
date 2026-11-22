---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Find A Privileged Pod And Block It With Pod Security Admission

Allow about 12 minutes for the tasks.

A routine check of the `starfleet-036-040-02-02` crew finds that one workload runs with nearly the full rights of the node. Find the Pods with extra rights, record them, make the namespace reject privileged Pods and run the workload again without privileged mode.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-040-02-02` runs the `probe` Deployment, the `telemetry-agent` Deployment and the Pods `shuttle`, `node-inspector` and `beacon`. The namespace `outpost-036-040-02-02` runs the `drifter` Pod. The namespace `starfleet-036-040-02-02` has no Pod Security Admission label.

Use the private kubeconfig for `ats-036-lab-040-02-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-02-02)"` and check that the context is `kind-astro-ats-036-lab-040-02-02`.

## Tasks

1. Inspect the Pods and workloads in `starfleet-036-040-02-02`. Create the ConfigMap `privilege-finding` in that namespace with three keys: `privilegedWorkload` (the name of the Deployment whose Pod runs a privileged container), `privilegedContainer` (the name of that container) and `hostPIDPod` (the name of the Pod that shares the process namespace of the node).
2. Label the namespace `starfleet-036-040-02-02` so that Pod Security Admission enforces the `baseline` Pod Security Standard with version `latest`. Read the warnings that kubectl prints.
3. Prove with a server-side dry run that the API server now rejects a new Pod with `privileged: true` in that namespace.
4. Change the `telemetry-agent` Deployment so that its container `agent` no longer runs privileged, and wait until its new Pod is ready. Keep the container name and image. Delete the Pod `node-inspector`; it is not needed.

## Constraints

Do not change or delete the `probe` Deployment and the Pods `shuttle`, `beacon` and `drifter`.

Work only in this lab's namespaces `starfleet-036-040-02-02` and `outpost-036-040-02-02`.

## How the answer is checked

Each check gives one point: the ConfigMap `privilege-finding` records the privileged workload, its container and the Pod that shares the process namespace of the node; the namespace enforces the `baseline` or `restricted` Pod Security Standard and the API server rejects a privileged Pod in a server-side dry run; the `telemetry-agent` Deployment is ready without a privileged container and no Pod in the namespace is privileged or uses `hostPID`. The grader reads the live objects and sends its own test Pod with a server-side dry run, so nothing is stored.
