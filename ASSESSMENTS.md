# Reusable Question Banks

`assessments/index.yaml` lists banks in teaching order. Each bank uses schema
version 1 and the contract in `schemas/question-bank.schema.json`. This is an
authoring format for future application integration, not an existing Astrona
quiz API. No YAML question file is registered as a Markdown reading.

Banks follow their declared module summaries. Larger domains use an intermediate
checkpoint after the third section and a final domain review; smaller domains
use a final domain review. The index records covered sections and teaching order. Banks contain 5–15 original single-choice
questions, scoped to concepts taught in the course. They remain draft for review.

## Fields And Rendering

- `id`: stable bank or question identity; preserve it when editing wording.
- `scope`: section or domain checkpoint.
- `placement`: relative reading path after which the checkpoint belongs.
- `learning_objective`: the measurable outcome checked by the question.
- `source_readings`: author traceability to the teaching; not learner navigation.
- `prompt`: learner-visible question text.
- `options`: stable option IDs, answer text and per-option feedback.
- `correct_option`: the ID of the single correct option.
- `explanation`: feedback reinforcing the supported answer.

The application should send only the question ID, prompt and option IDs/text to
the learner before submission. Keep `correct_option`, `explanation` and option
explanations on the server until feedback is permitted. Match answers by option
ID, not display position, so a later renderer can shuffle choices safely.

The banks contain answer keys and are public learning material, so this is not
a secure examination bank. Do not treat scores as an official CKS result.

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
