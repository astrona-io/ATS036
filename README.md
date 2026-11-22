<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS036.svg" alt="ATS036: Monitoring, Logging and Runtime Security, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Monitoring, Logging and Runtime Security (ATS036)

Certified Kubernetes Security Specialist (CKS): Monitoring, Logging and Runtime Security, worth 20% of the official curriculum. This course belongs to ATP007.

Each module has a landing page, deep-dive parts, a summary and a knowledge check. Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Private playgrounds and graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Behavioral Detection With Runtime Context | Expected Behavior Of A Workload; Syscalls, eBPF And Falco Rules; Audit Records As Behavioral Evidence; Triage, Tuning And Response To An Alert |
| 010 / 02 | Writing Runtime Detection Rules | Anatomy Of A Falco Rule File; Scope A Shell Rule To A Namespace; Exceptions, Testing And Limits Of A Rule; Test A Live Sensor In A Linux VM; Join A Runtime Event To Kubernetes Identity |
| 010 / 03 | Detecting Command Execution Through API Audit Records | Exec And Port-Forward In The Audit Log; Who Sent The Request: Identity And Origin; Correlating Audit Records With Other Evidence |
| 020 / 01 | Security Observability And Evidence Quality | Security Signals By Layer; Workload Logs, Restarts And Exit Evidence; Network Traffic, Application Logs And Evidence Gaps |
| 020 / 02 | Detecting Risky Workloads From Events, Specifications And Logs | Kubernetes Events As A Short-Lived Signal; Reading A Pod Specification For Risky Settings; Application Log Signals Of Abuse |
| 020 / 03 | Detecting Threats To Data And User Accounts | ServiceAccounts And User Identity; Who Can Read Secrets; Secret Exposure Paths |
| 030 / 01 | Reconstructing Attack Phases And Actor Authority | Attack Phases In Kubernetes; Actor Identity In Audit Records; Building A Timeline From Several Sources; Containment And Evidence Preservation |
| 030 / 02 | Finding Persistence And Escalated Authority | Persistence In Workload Templates And Schedules; Privilege Escalation Through Bindings And Pod Settings |
| 030 / 03 | Tracing Lateral Movement And Impact | Lateral Movement And Network Evidence; Impact And Resource Abuse |
| 040 / 01 | Constraining Runtime Mutation And Writable Paths | The Writable Container Layer; Read-Only Root Filesystem And Security Context; Limits Of A Read-Only Filesystem And Pod Security Admission; Verifying And Enforcing Immutability |
| 040 / 02 | Dropping Privileges: Identity, Capabilities And Privilege Escalation | Linux Capabilities And What A Container Starts With; Non-Root Identity And Privilege Escalation; Privileged Containers And Verifying Process Privileges |
| 040 / 03 | Host Mounts And Replacement-Based Updates | Volumes That Reach The Host; Updating By Replacement; Pinning Images And Detecting Drift |
| 050 / 01 | Using Kubernetes Audit Logs To Monitor Access | The Audit Event Model; Writing An Audit Policy; API Server Flags, Backends And Troubleshooting; Reading Audit Records To Monitor Access |
| 050 / 02 | Auditing Interactive Access To Pods | Subresources In Audit Policy Rules; Recording And Reading Exec Events; Choosing Rules And Levels For Interactive Access |
| 050 / 03 | Retaining And Protecting Audit Logs | Rotation Flags And Disk Use; Protecting The Log File; Forwarding And Retention Policy; Verify Delivery To An Audit Webhook |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). Runtime results are recorded in the PR and GitHub Actions.

## Hands-On Coverage

This course has 15 ungraded module playgrounds (all on kind) and 26 graded labs (23 on kind, 3 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Each module also has a knowledge check of 10 questions. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`. The three qemu labs need their own Linux kernel or host services: two run Falco with a live eBPF sensor (one on the host, one as a Helm release that adds Kubernetes metadata), and one sends audit events over TLS to a webhook collector outside the control plane container.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Detect A Denied API Access Attempt; Quarantine A Suspicious Pod Without Deleting It |
| 010/02 | Write A Scoped Shell Detection Rule; Test A Falco Rule Against Live Processes; Scope Live Falco Events With Kubernetes Metadata |
| 010/03 | Find The Audit Record Of A Pod Exec; Link An Exec Audit Record To Its Node And Container |
| 020/01 | Diagnose A Previous Container Exit; Find A Pod's Log Files On Its Node |
| 020/02 | Report A Risky Pod Specification; Count Failed Logins In An Application Log |
| 020/03 | Find Which Account Can Read Secrets; Move A Secret From An Environment Variable To A Read-Only Volume |
| 030/01 | Attribute An API Attempt To A Workload Identity; Isolate A Compromised Pod And Revoke Its Token |
| 030/02 | Stop A Persistent CronJob Without Deleting It; Contain A Persistent Workload And Its Binding |
| 030/03 | Trace A Connection To Its Source Pod; Find And Limit A Workload That Can Exhaust Its Node |
| 040/01 | Run With A Restricted Security Context |
| 040/02 | Drop All Capabilities And Block Privilege Escalation |
| 040/03 | Update A Workload By Replacement With A Read-Only Root |
| 050/01 | Verify Metadata Audit Records Exclude Secret Payloads |
| 050/02 | Record Interactive Pod Access In The Audit Log |
| 050/03 | Record The Audit Retention Settings And Log File Protection; Deliver Audit Metadata Outside The Control Plane |

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.

See [lesson and lab links](LAB-COVERAGE.md) and [remaining practical gaps](COVERAGE-REVIEW.md) for the current assessment scope.
