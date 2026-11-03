---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The `probe` Deployment in `starfleet` runs as root with default capabilities and a writable root filesystem. The `shuttle` Pod in `starfleet` and the `drifter` Pod in `outpost` are healthy. Complete the required change without replacing unrelated resources.

Harden Deployment `probe` in `starfleet` through its Pod template, and keep `VERSION` at `v1`. The Pod must run as user and group 10001 with `runAsNonRoot: true` and RuntimeDefault seccomp. The `probe` container must have a read-only root filesystem, disable privilege escalation and drop all capabilities. Keep the existing `app` volume and its read-only mount first, then add an `emptyDir` volume named `tmp` mounted at `/tmp`. Then create ValidatingAdmissionPolicy `require-read-only-root` and ValidatingAdmissionPolicyBinding `require-read-only-root`. The policy must reject `CREATE` of Pods whose containers do not set `readOnlyRootFilesystem` to true. The binding must use the `Deny` action and apply only to the `starfleet` namespace. The service must keep answering with `version=v1`. A new Pod with a writable root filesystem must be rejected in `starfleet` and accepted in `outpost`.
