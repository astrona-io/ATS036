---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Choosing Rules And Levels For Interactive Access

Recording every request to every Pod subresource fills the log quickly, because controllers and monitoring tools read Pod logs all the time. A good policy records the interactive requests that matter and drops the rest. This part covers the order of rules, the filters that narrow a rule and the level to use for subresources.

## Order decides what is recorded

The API server compares a request with the rules from the first to the last. The first rule that matches sets the level, and no later rule is read. Two orders show the effect. Consider these two rules for the same cluster:

```yaml
rules:
- level: None
  users: ["system:kube-proxy"]
- level: Metadata
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]
```

The first rule drops the noisy requests of one component. The second records every interactive request from everybody else. If the order were reversed, the result would be the same here, because the two rules do not overlap. The order matters when they do overlap. A rule that sets `level: None` for the group `system:nodes` placed above the exec rule would hide an exec request that comes from a node identity. Put the narrow rules first and the broad rules last.

## Filters that narrow a rule

A rule can combine several filters. All filters in one rule must match.

| Field | What it selects |
| --- | --- |
| `users` | Authenticated user names. |
| `userGroups` | Groups of the authenticated user. |
| `verbs` | Request verbs such as `get` or `create`. |
| `namespaces` | Namespaces. An empty string selects cluster-scoped requests. |
| `resources` | API groups, resource names, subresources and optional `resourceNames`. |
| `nonResourceURLs` | Paths such as `/healthz*`. |

The field `resourceNames` narrows a rule to named objects. A rule for `pods/exec` with `resourceNames: ["shuttle"]` records exec only for that Pod. This is useful for a small set of sensitive workloads, but it leaves other Pods unaudited. For access monitoring, prefer to record all exec requests and filter noise by user.

## The level for subresources

Exec, attach and port-forward requests carry the command and the container in the query string, and they carry no object body that holds secrets. The `Metadata` level records the query string in `requestURI`, so it holds everything the API server knows about the request. The `Request` level adds the request body. For a streaming request the body is empty, so the extra level only adds size.

The risk is on the other side. The subresource `serviceaccounts/token` returns a new token in the response. A rule at `RequestResponse` for it writes a working credential into the log. Record token requests at `Metadata`, the same as Secrets.

## Reviewing a policy

Review a policy with four questions. Does a rule name each interactive subresource? Is any broad rule placed above them? Does the last rule record the remaining requests at `Metadata`, or does it drop them with `None` on purpose? Does any rule write a body that can hold a credential? A policy that passes these questions gives an investigator the identity, the Pod and the command for each interactive request.

This part closed the module's argument. Interactive access is recorded only when a rule names the subresource, the order of the rules lets the request reach that rule, and the level keeps credentials out of the file.

## Common pitfalls

> [!WARNING]
> - **Dropping node identities with a broad `None` rule.** Place it below the interactive rules.
> - **Using `resourceNames` to save space.** Pods that are not listed leave no record.
> - **Raising the level for token requests.** `RequestResponse` writes the token.
> - **Ending the policy without a final rule.** A request that matches no rule is not recorded.
