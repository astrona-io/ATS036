---
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Quarantine A Suspicious Pod Without Deleting It

Allow about 8 minutes for the tasks.

A runtime alert reports that a shell started in one of the `probe` Pods in `starfleet-036-010-01-02` and wrote a file. Keep that Pod for analysis, but stop all traffic to it and let the Deployment replace it.

## Objective

Capture evidence from a running Pod with an ephemeral container, then quarantine the Pod by changing its labels so that the Deployment and the Service no longer select it.

Solve this question on: `terminal`

## Starting state

The `probe` Deployment runs two replicas behind the `probe` Service. The Deployment and the Service both select Pods with the labels `app=probe` and `release=probe`. The ConfigMap `shell-alert` holds the alert: the name of the suspect Pod (`pod`), its UID (`uid`), the container (`container`) and the rule that fired (`rule`).

Use the private kubeconfig for `ats-036-lab-010-01-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-010-01-02)"` and check that the context is `kind-astro-ats-036-lab-010-01-02`.

## Tasks

1. Read the ConfigMap `shell-alert` and find the suspect Pod.
2. Add an ephemeral container named `evidence` to the suspect Pod. Use the image `docker.io/library/busybox:1.37.0`, target the `probe` container and list its processes.
3. Quarantine the suspect Pod: remove its `app` and `release` labels and add the label `quarantine=true`. Do not delete the Pod.
4. Check that the Deployment has two available replicas again and that the `probe` Service no longer sends traffic to the suspect Pod.

## Constraints

Work only in the namespaces `starfleet-036-010-01-02` and `outpost-036-010-01-02`. Do not delete, restart or recreate the suspect Pod: the grader compares its UID with the alert. Do not change the Deployment or the Service.

## How the answer is checked

Each check gives one point: an ephemeral container named `evidence` ran in the suspect Pod and targeted its `probe` container; the suspect Pod keeps running with the same UID, without its `app` and `release` labels and with `quarantine=true`; the `probe` Service no longer lists the suspect Pod and the Deployment again has two available replicas.
