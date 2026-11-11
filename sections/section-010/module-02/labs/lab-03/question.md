---
draft: true
---
# Scope Live Falco Events With Kubernetes Metadata

Solve this question on: `terminal`

This independent Ubuntu VM runs a kind cluster, Falco, the Kubernetes metadata collector and its plugin. Both `monitored` and `outside` contain a `reporter` Pod. The custom rule currently selects a nonexistent namespace.

Allow 10–15 minutes for task work. VM, cluster and sensor startup add several minutes.

## Tasks

1. Repair `customRules.training.yaml` in `/etc/training/values.yaml`. Rule `Training namespace shell` must detect completed `execve` or `execveat` events for `sh` and `bash` in namespace `monitored`, excluding commands whose command line contains `approved-`. Include command, namespace, Pod name and Pod UID in its output.
2. Upgrade the installed release using the cached Falco chart, restart the DaemonSet and wait for the sensor to become ready.
3. Test fresh events. Prove unexpected monitored shells alert, approved commands and outside shells do not, and a subsequent unexpected monitored shell still alerts.

## Constraints

Use `/etc/training/kubeconfig`. Preserve Pods, namespaces, metadata collection and JSON output. Do not replace live events with saved log records or disable the sensor. Keep the existing rule name so the assessment can distinguish your custom event from default rules.

## How the answer is checked

The grader generates unique process markers and reads current Falco JSON logs. It checks real namespace, Pod name and UID, then tests both excluded cases between two required alerts.
