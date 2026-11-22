---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Fix An Audit Policy That Misses Pod Exec Requests

Allow about 15 minutes for the tasks.

Someone opened a shell in the `shuttle` Pod of `starfleet-036-050-02-02`, and the audit log has no trace of it. Fix the audit policy so that the next exec or port-forward request is recorded.

Solve this question on: `terminal`

## Starting state

The namespace `starfleet-036-050-02-02` runs the Pod `shuttle` and the Service `probe` on port 80. The API server reads its audit policy from `/etc/kubernetes/training-audit-policy.json` on the control plane node and writes events to `/var/log/training-audit/audit.jsonl` on the same node. Today a `kubectl exec` request leaves no record in that log.

Use the private kubeconfig for `ats-036-lab-050-02-02`. In a local lab, select it with `export KUBECONFIG="$(astrona kubeconfig ats-036-lab-050-02-02)"` and check that the context is `kind-astro-ats-036-lab-050-02-02`. The control plane node container is `astro-ats-036-lab-050-02-02-control-plane`.

## Tasks

1. Read the audit policy on the control plane node and find why `pods/exec` and `pods/portforward` requests reach no recording rule.
2. Change the policy so that the first matching rule for `pods/exec` and `pods/portforward` requests sets `level: Metadata`. Keep the rule that drops the other Pod subresources, such as `pods/log` and `pods/status`, with `level: None`. Keep the file in JSON format at the same path.
3. Restart the API server so that it reads the new policy, and wait until it answers again.
4. Run a command in Pod `shuttle` with `kubectl exec` and open a `kubectl port-forward` session to the Service `probe`. Check that the audit log holds a record of both requests.

## Constraints

Work only in this lab's namespace `starfleet-036-050-02-02` and its own node containers. Do not change the audit flags, volumes or mounts of the API server manifest. Do not record Pod subresource requests at the levels `Request` or `RequestResponse`.

## How the answer is checked

Each check gives one point: the policy file sends `pods/exec` and `pods/portforward` requests to a `Metadata` rule first and still drops `pods/log` and `pods/status`; a new exec request that the grader sends in Pod `shuttle` leaves a `Metadata` record without bodies; the log holds a `Metadata` record of a `pods/portforward` request in `starfleet-036-050-02-02`. The grader reads the policy file and the audit log on the node live.
