---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Starting Environment

Pod `crash-report` prints a start marker, exits once with a nonzero status and then stays running after its restart. An emptyDir marker prevents further crashes so the previous logs remain available. The healthy probe application is separate from that evidence Pod.

Leave Pod `crash-report` running its original command. Read the previous instance of container `report`. Create ConfigMap `crash-diagnosis` with `container: report`, `exitCode` matching the last terminated instance, and `logMarker: application-started`. The Pod must have restarted at least once and its previous log must contain the marker. Do not delete or repair the evidence Pod.
