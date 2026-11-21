# Curriculum Coverage

> Historical design record. Counts and execution claims below describe the original expansion. For current labs, preparation and practical limits, use [LAB-COVERAGE.md](LAB-COVERAGE.md) and [COVERAGE-REVIEW.md](COVERAGE-REVIEW.md).

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Monitoring, Logging and Runtime Security (20%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Perform behavioral analytics to detect malicious activities | 1 |
| 020 | Detect threats within physical infrastructure, apps, networks, data, users and workloads | 1 |
| 030 | Investigate and identify phases of attack and bad actors within the environment | 1 |
| 040 | Ensure immutability of containers at runtime | 1 |
| 050 | Use Kubernetes audit logs to monitor access | 1 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Behavioral Detection With Runtime Context | Behavioral Detection With Runtime Context |
| 020 / 01 | Security Observability And Evidence Quality | Collection, Storage And Observation Limits; Security Signals Across Different Boundaries |
| 030 / 01 | Reconstructing Attack Phases And Actor Authority | Reconstructing Attack Phases And Actor Authority |
| 040 / 01 | Constraining Runtime Mutation And Writable Paths | Constraining Runtime Mutation And Writable Paths |
| 050 / 01 | Audit Policy And Security Evidence | Designing Useful And Protected Audit Records |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. Question banks are separate from the reading manifest and follow their declared summaries. No labs, playgrounds or runtime validation are included.

## Hands-On Coverage

This course has 15 ungraded module playgrounds (all on kind) and 18 graded labs (15 on kind, 3 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Each module also has a knowledge check of 10 questions. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`. The three qemu labs need their own Linux kernel or host services: two run Falco with a live eBPF sensor (one on the host, one as a Helm release that adds Kubernetes metadata), and one sends audit events over TLS to a webhook collector outside the control plane container.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Detect A Denied API Access Attempt |
| 010/02 | Write A Scoped Shell Detection Rule; Test A Falco Rule Against Live Processes; Scope Live Falco Events With Kubernetes Metadata |
| 010/03 | Find The Audit Record Of A Pod Exec |
| 020/01 | Diagnose A Previous Container Exit |
| 020/02 | Report A Risky Pod Specification |
| 020/03 | Find Which Account Can Read Secrets |
| 030/01 | Attribute An API Attempt To A Workload Identity |
| 030/02 | Contain A Persistent Workload And Its Binding |
| 030/03 | Trace A Connection To Its Source Pod |
| 040/01 | Run With A Restricted Security Context |
| 040/02 | Drop All Capabilities And Block Privilege Escalation |
| 040/03 | Update A Workload By Replacement With A Read-Only Root |
| 050/01 | Verify Metadata Audit Records Exclude Secret Payloads |
| 050/02 | Record Interactive Pod Access In The Audit Log |
| 050/03 | Record The Audit Retention Settings And Log File Protection; Deliver Audit Metadata Outside The Control Plane |
