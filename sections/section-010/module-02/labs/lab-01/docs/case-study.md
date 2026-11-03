---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. No detection rule has been stored yet. The environment does not run Falco, so the rule is stored as text in a ConfigMap and checked for its fields.

Write a runtime detection rule that reports shells started in the starfleet namespace.
