# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Remaining practical gaps and boundaries

- The new QEMU lab runs real Falco with positive and negative process events. It scopes host accounts; it does not verify Kubernetes metadata enrichment or namespace-scoped detection. The kind lab checks that rule document separately.
- Audit retention grading reads live flags and permissions; it does not wait for age-based deletion or prove off-node delivery. Webhook forwarding and retention design are reference topics.
- Physical infrastructure telemetry and a complete incident response program exceed the local fixtures. Investigation labs grade evidence from the supplied Kubernetes incident.

These are explicit limits, not completed assessments. When closing one, add or extend a runnable environment, teach the actual commands and evidence, add a live grader with negative cases, and update the mapping. Do not mark a reference procedure as practiced just because it contains a command block.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
