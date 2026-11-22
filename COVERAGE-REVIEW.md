# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible.

## Live assessment additions

New QEMU labs collect real Falco events with Kubernetes namespace, Pod name and UID, and deliver scoped API audit events over authenticated TLS to a receiver outside the control-plane container. Negative cases test an overly broad detection rule and disclosure of Secret bodies.

## Skills from the removed section capstones

The five section capstones were removed so that every graded lab is a focused task that can join a lab exam. Each capstone combined skills from its section. The lists below name each graded skill and the module lab that still grades it. A skill marked "not graded" has teaching but no module lab yet. Later changes added module labs for most of the skills that were not graded.

Section 010, Report And Contain Suspicious Behavior From Audit Evidence:

- Copy the actor and audit ID from the `ResponseComplete` record of a denied (403) Secret request: section 010 module 01 lab 01.
- Copy the actor, audit ID, stage and Pod name from the audit record of an `exec` request: section 010 module 03 lab 01.
- Quarantine a Pod by removing its `app` and `release` labels and adding `quarantine=true`, so that the Service stops sending it requests and the Deployment returns to two other replicas, without deleting the Pod: section 010 module 01 lab 02.

Section 020, Triage Four Findings And Revoke Secret Access:

- Exit code of the previous container instance: section 020 module 01 lab 01.
- Count the `login failed` lines in an application log: section 020 module 02 lab 02.
- Name the privileged Pod: section 020 module 02 lab 01.
- Name the ServiceAccount that can read Secrets: section 020 module 03 lab 01.
- Revoke access by deleting one RoleBinding and keeping a legitimate one: section 030 module 02 lab 01. No section 020 lab removes a binding.

Section 030, Investigate And Contain A Multi-Phase Incident:

- Actor and audit ID of a denied Secret read: section 030 module 01 lab 01.
- Persistence Deployment and its RoleBinding; scale the Deployment to zero, delete the binding and keep `probe-reader-view`: section 030 module 02 lab 01.
- Source Pod, namespace and IP address of unexpected requests to the `probe` Service: section 030 module 03 lab 01.
- Combine the three findings into one report with the attack phases: not graded.
- Label the intruding Pod `incident=quarantine` without deleting it: section 030 module 01 lab 02.

Section 040, Harden A Workload And Enforce A Read-Only Root Filesystem Policy:

- Non-root user and group, `runAsNonRoot`, RuntimeDefault seccomp, no privilege escalation and no capabilities: section 040 module 01 lab 01 and section 040 module 02 lab 01.
- Read-only root filesystem through a Deployment Pod template, with the read-only `app` mount and an `emptyDir` at `/tmp`: section 040 module 03 lab 01.
- A ValidatingAdmissionPolicy and ValidatingAdmissionPolicyBinding that reject new Pods without `readOnlyRootFilesystem: true` in one namespace and accept them in another: section 040 module 01 lab 02.

Section 050, Investigate Secret, Denied And Exec Access From The Audit Log:

- Audit ID of a successful Secret read with no request or response body: section 050 module 01 lab 01.
- Audit ID of a denied Secret read: section 010 module 01 lab 01 and section 030 module 01 lab 01. There the setup sends the denied request. Section 050 module 01 lab 02 asks the learner to send it with `kubectl --as` and find its record.
- Audit ID of an `exec` request that runs `id` in `shuttle`: section 050 module 02 lab 01.

## Remaining practical gaps and boundaries

- Falco tests use controlled shell events and an explicit command exception; they do not establish complete intrusion detection.
- The audit receiver shares the disposable VM. Delivery is tested, but durable off-VM storage, retention expiry and disaster recovery are not.
- Physical infrastructure telemetry and a complete incident-response exercise remain outside these fixtures.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
