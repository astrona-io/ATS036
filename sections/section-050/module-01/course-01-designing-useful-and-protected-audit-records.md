---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Designing Useful And Protected Audit Records

A deployment identity creates an unexpected workload. Kubernetes audit records can help establish who requested the change, which resource it targeted and what response the application programming interface (API) produced. Auditing is evidence about API activity; it does not automatically observe every command or file access inside a running container.

## Recorded Context And Stages

An audit event can include caller identity, request verb, resource reference, timestamps, response status and other configured context. Stages describe points in the request lifecycle, such as receipt or completion. Several records can relate to one request, so correlation and stage interpretation matter when counting actions.

A successful response supports that an API action was accepted according to its semantics. It does not prove the resulting workload later became ready or that its application behavior was legitimate. A rejected action can still be important evidence of attempted misuse, but it should not be described as a completed resource change.

Identity is also not the same as the human who intended an operation. A shared token or compromised automation credential can produce requests under a legitimate identity. Attribution needs credential ownership, client context and related records rather than assuming the displayed user name proves a person's intent.

## Policy Detail And Sensitivity

An audit policy selects which events and detail levels to record. Metadata records request context without the full body. Request can include the submitted object. RequestResponse can include request and response bodies. More detail can improve some investigations while increasing storage, performance and confidentiality concerns.

A body containing a Secret or sensitive custom resource can disclose credentials or data through the audit system. Choosing maximum detail everywhere is therefore not automatically best. Define the investigation need, sensitive resource types and protected access path for retained records.

Policy rule order matters because matching determines which recording behavior applies. A broad earlier rule can make later specific intent ineffective. Review the effective policy rather than assuming the presence of a detailed rule guarantees its use for every relevant action.

## Retention And Pipeline Integrity

Records must reach their intended destination reliably. Local storage can be lost with a node or control plane instance, while an external collection path can fail because of credentials, capacity or connectivity. Monitor collection health and define appropriate handling when evidence cannot be retained.

Restrict who can read, change or delete audit records. A compromised administrator may try to reduce future recording or erase accessible history. Separate storage and retention controls can help preserve investigation evidence, though the protection depends on the actual operating environment.

Time synchronization and stable correlation improve reconstruction. Retention must cover the interval in which an incident may be discovered. An expired record cannot support a later claim about what a caller did, and absence caused by policy or collection failure is not evidence that no action occurred.

## Working Through The Unexpected Workload

Find the request that created the object, its authenticated identity and response outcome. Then inspect the effective grants and the resulting workload's image, privileges, mounts and external access. Audit history can explain API intent, while runtime and application evidence explain what happened after execution.

If the credential was exposed, revoke or rotate it and examine other permitted actions during its validity. Restore reviewed state and consider persistent data or external systems the workload could access. Audit evidence supports scope; it is not a corrective control that automatically reverses misuse.

A sound audit design balances relevant detail, sensitive-data protection and durable availability. Explain exactly which question the records can answer and which needs another observation source.

## Common pitfalls

> [!WARNING]
> Audit records describe configured API evidence, not every container action. Request bodies can contain secrets, and missing records can reflect policy, retention or collection failure.
