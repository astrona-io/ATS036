---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Enforce A Read-Only Root Filesystem With A ValidatingAdmissionPolicy

Allow about 10 minutes for the tasks.

The `starfleet-036-040-01-02` crew must only launch Pods that cannot change their own files, while the `outpost-036-040-01-02` team keeps its current freedom for now. Reject new Pods without a read-only root filesystem in one namespace and keep the other namespace open.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-040-01-02` runs the `probe` Deployment with two replicas and the `shuttle` Pod. The namespace `outpost-036-040-01-02` runs the `drifter` Pod. None of these Pods sets `readOnlyRootFilesystem`. No ValidatingAdmissionPolicy and no namespace label for this lab exist yet.

Use the private kubeconfig for `ats-036-lab-040-01-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-040-01-02)"` and check that the context is `kind-astro-ats-036-lab-040-01-02`.

## Tasks

1. Add the label `immutability=enforced` to the namespace `starfleet-036-040-01-02`. Do not add it to `outpost-036-040-01-02`.
2. Create the ValidatingAdmissionPolicy `require-read-only-root-036-040-01-02`. It matches `CREATE` and `UPDATE` requests for `pods` in the core API group, version `v1`, keeps `failurePolicy: Fail`, and has one validation: every entry in `spec.containers` sets `securityContext.readOnlyRootFilesystem` to `true`. Use the message `Every container must set readOnlyRootFilesystem to true.`
3. Create the ValidatingAdmissionPolicyBinding `require-read-only-root-starfleet-036-040-01-02` for that policy with `validationActions: ["Deny"]`. Select the namespaces with a `namespaceSelector` on the label `immutability=enforced`.
4. Verify with server-side dry runs: a Pod with a writable root filesystem is rejected in `starfleet-036-040-01-02` and accepted in `outpost-036-040-01-02`, and a Pod whose containers all set `readOnlyRootFilesystem: true` is accepted in `starfleet-036-040-01-02`.

## Constraints

Do not delete, restart or change the running `probe`, `shuttle` and `drifter` workloads. They must keep running after the policy is active.

Work only in this lab's namespaces `starfleet-036-040-01-02` and `outpost-036-040-01-02` and the two cluster-scoped objects named above. Do not bind the policy to other namespaces.

## How the answer is checked

Each check gives one point: the bound policy denies a new Pod in `starfleet-036-040-01-02` when any container leaves the root filesystem writable, with the policy name and message in the error; the bound policy accepts a new Pod whose containers all set `readOnlyRootFilesystem: true`; the binding selects namespaces by label, `outpost-036-040-01-02` still accepts a writable Pod, and the running Pods keep running. The grader sends its own Pods with server-side dry runs, so nothing is stored.
