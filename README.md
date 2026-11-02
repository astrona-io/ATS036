# Monitoring, Logging and Runtime Security (ATS036)

Certified Kubernetes Security Specialist (CKS): Monitoring, Logging and Runtime Security, worth 20% of the official curriculum. This course belongs to ATP007.

Each module has a landing page, deep-dive parts, a summary and a knowledge check. Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Behavioral Detection With Runtime Context | Expected Behavior Of A Workload; Syscalls, eBPF And Falco Rules; Audit Records As Behavioral Evidence; Triage, Tuning And Response To An Alert |
| 020 / 01 | Security Observability And Evidence Quality | Security Signals By Layer; Workload Logs, Restarts And Exit Evidence; Network Traffic, Application Logs And Evidence Gaps |
| 030 / 01 | Reconstructing Attack Phases And Actor Authority | Attack Phases In Kubernetes; Actor Identity In Audit Records; Building A Timeline From Several Sources; Containment And Evidence Preservation |
| 040 / 01 | Constraining Runtime Mutation And Writable Paths | The Writable Container Layer; Read-Only Root Filesystem And Security Context; Limits Of A Read-Only Filesystem And Pod Security Admission; Verifying And Enforcing Immutability |
| 050 / 01 | Using Kubernetes Audit Logs To Monitor Access | The Audit Event Model; Writing An Audit Policy; API Server Flags, Backends And Troubleshooting; Reading Audit Records To Monitor Access |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). No runtime execution is claimed.

## Hands-On Coverage

This course has 5 ungraded module playgrounds and 5 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Each module also has a knowledge check of 10 questions. Static and offline checks pass. Live execution of the playgrounds and labs has not been recorded.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Detect A Denied API Access Attempt |
| 020/01 | Diagnose A Previous Container Exit |
| 030/01 | Attribute An API Attempt To A Workload Identity |
| 040/01 | Run With A Restricted Security Context |
| 050/01 | Verify Metadata Audit Records Exclude Secret Payloads |
