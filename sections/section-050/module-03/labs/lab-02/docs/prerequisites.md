---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Prerequisites

Use astrona and a terminal. Every command runs in a shell on the lab VM (virtual machine), not on your own computer.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-036-lab-050-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-036-lab-050-03-02`. You are logged in as the `student` user. The files in `/etc/kubernetes` belong to root, so run node commands with `sudo`.
