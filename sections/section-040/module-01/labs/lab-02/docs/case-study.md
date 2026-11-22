---
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The namespace `starfleet-036-040-01-02` runs the `probe` Deployment with two replicas and the `shuttle` Pod. The namespace `outpost-036-040-01-02` runs the `drifter` Pod. None of these Pods sets `readOnlyRootFilesystem`, so every root filesystem is writable.

The team wants the API server to reject new Pods with a writable root filesystem in `starfleet-036-040-01-02` only. A ValidatingAdmissionPolicy holds the rule, and a ValidatingAdmissionPolicyBinding with a `namespaceSelector` limits it to the namespaces with the label `immutability=enforced`. The running Pods were admitted before the policy existed. The API server does not check them again, so they keep running.
