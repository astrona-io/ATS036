---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Starting Environment

The `probe` Deployment runs version `v1` with a writable root filesystem. The `shuttle` Pod can call the `probe` Service. Complete the required change without replacing unrelated resources.

Change Deployment `probe` in `starfleet-036-040-03-01` through its Pod template. Set the `VERSION` environment variable to `v2`. Set `readOnlyRootFilesystem: true` on the `probe` container. Keep the existing `app` volume and its read-only mount first, then add an `emptyDir` volume named `tmp` mounted at `/tmp`. Do not use a `hostPath` volume. The rollout must finish with two ready replicas, the service must answer with `version=v2`, writing to `/tmp` must work, and writing `/root-file` must fail.
