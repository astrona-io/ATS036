# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Live assessment additions

New QEMU labs collect real Falco events with Kubernetes namespace, Pod name and UID, and deliver scoped API audit events over authenticated TLS to a receiver outside the control-plane container. Negative cases test an overly broad detection rule and disclosure of Secret bodies.

## Remaining practical gaps and boundaries

- Falco tests use controlled shell events and an explicit command exception; they do not establish complete intrusion detection.
- The audit receiver shares the disposable VM. Delivery is tested, but durable off-VM storage, retention expiry and disaster recovery are not.
- Physical infrastructure telemetry and a complete incident-response exercise remain outside these fixtures.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
