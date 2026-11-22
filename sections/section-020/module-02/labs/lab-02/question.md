---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Count Failed Logins In An Application Log

Allow about 8 minutes for the tasks.

The station's login service reported a burst of failed logins during the night shift, and the security officer wants the facts before anyone resets a password. Count the failed logins in the application log, find who was targeted and from where, and record whether the guessing worked. Use the isolated `starfleet-036-020-02-02` environment.

## Objective

Turn the lines of an application log into a short, checkable security finding.

Solve this question on: `terminal`

## Starting state

Pod `login-service` writes one line for every login attempt, in the form `login failed user=<name> src=<address>` or `login ok user=<name> src=<address>`. Its log also has start, health and ready lines. The probe application and the `shuttle` and `drifter` Pods are not part of the evidence.

Use the private kubeconfig for `ats-036-lab-020-02-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-02-02)"` and check that the context is `kind-astro-ats-036-lab-020-02-02`.

## Tasks

1. Read the log of Pod `login-service` in `starfleet-036-020-02-02` and count the lines that contain `login failed`.
2. Find the user and the source address that together have the most failed logins.
3. Check whether a login from that source address succeeded after its failures, and note the user of that successful login.
4. Create ConfigMap `login-findings` in `starfleet-036-020-02-02` with the keys `failedCount`, `targetUser`, `sourceAddress` and `successUser`, using the values you found.

## Constraints

Work only in this lab’s namespaces `starfleet-036-020-02-02` and `outpost-036-020-02-02`. Do not delete, change or restart Pod `login-service`: a new container starts a new log. Store every value as a string. Cluster startup adds time to the task estimate.

## How the answer is checked

Each check gives one point: the report records the number of failed login lines in the live application log; the report names the user and the source address of the repeated failures; the report names the user that logged in from the failing source address after the failures. The grader reads the live log of `login-service` and compares it with the report; it does not award points for preserving the starting state.
