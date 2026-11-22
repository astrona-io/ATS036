---
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Fix An Audit Policy That Misses Pod Exec Requests

The learner repairs an audit policy whose rule order and resource list hide `pods/exec` and `pods/portforward` requests, restarts the API server so that it reads the new file, and proves with real requests that both are now recorded at the Metadata level.

The lab runs in its own pinned kind cluster with one worker. `bootstrap/enable-audit.py` turns on a starting policy (written as indented JSON to `/etc/kubernetes/training-audit-policy.json` on the control plane node) whose first rule is `level: None` for `pods/*` and whose interactive-access rule names only `pods`. The reference solution copies `solution/training-audit-policy.json` to the node and restarts the API server by moving its static Pod manifest out of the manifests directory and back, with bounded waits.

Outcomes: `policy-order` (the policy file, evaluated with the API server's first-match rules, gives Metadata for `pods/exec` and `pods/portforward` and still None for `pods/log` and `pods/status`), `exec-recorded` (the grader sends a fresh exec with a random marker and finds its record within a bounded wait) and `portforward-recorded` (the log holds a Metadata record of a `pods/portforward` request in `starfleet-036-050-02-02`; the starting policy can never write one). Run `testing/smoke.sh` with the lab context selected to check that the starting state fails and the reference solution passes. Static validation is not live evidence; runtime verification remains pending.
