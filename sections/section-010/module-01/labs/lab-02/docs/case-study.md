---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The `probe` Deployment runs two replicas of a small Python web server behind the `probe` Service. A shell in the first `probe` Pod wrote the file `/tmp/dropped-tool`, and the ConfigMap `shell-alert` records that Pod's name and UID.

Keep the suspect Pod running. Add an ephemeral container named `evidence` that targets the `probe` container. Remove the `app` and `release` labels from the suspect Pod and add `quarantine=true`. The ReplicaSet then creates a replacement Pod, and the Service sends requests only to the two Pods that still carry both labels.
