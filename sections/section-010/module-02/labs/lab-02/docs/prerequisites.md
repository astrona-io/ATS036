---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Prerequisites

Use astrona and a terminal. Every command runs in a shell on the lab VM (virtual machine), not on your own computer.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-010-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-010-02-02`. You are logged in as the `student` user. Falco files and the Falco service belong to root, so run those commands with `sudo`.
