---
draft: true
exam_objectives:
- Investigate and identify phases of attack and bad actors within the environment
---
# Reconstructing Attack Phases And Actor Authority

Incident investigation reconstructs what happened, which authority enabled it and what remains affected. Kubernetes environments produce evidence at several boundaries: application requests, API decisions, host processes, network flows and external identity systems. Attack phases provide a useful organizing framework, but the timeline must distinguish actual observations from inferred explanations.

## Start With A Time And Identity Model

Record the affected workload's namespace, object UID, node, image reference and lifecycle interval. A Pod name can be reused after replacement, while its UID distinguishes the object instance. Time synchronization and time zones affect whether records from different systems can be ordered reliably. If clocks differ, record the uncertainty rather than force an unjustified exact sequence.

A Kubernetes audit username identifies the credential used in a request. It does not by itself identify the human controlling that credential. A ServiceAccount token can be used outside its expected workload if stolen, and an administrator credential can be copied. Attribution should therefore separate presented identity, observed source and hypotheses about the actor.

## Link The Observed Phases

Initial access might appear as a malicious application request followed by unexpected process execution. Credential access might appear as a sensitive file read or a Secret retrieval. Privilege escalation might involve a changed binding, a privileged workload or access to a host runtime socket. Persistence can involve a modified controller template, scheduled workload or external credential rather than only a process that survives temporarily.

The phases need not occur in a fixed textbook order. An actor with stolen administrative credentials may begin with broad authority, while an application exploit may never reach the API. Use the framework to ask what evidence would support each hypothesis, not to invent missing steps because an attack narrative seems familiar.

## Correlate Independent Sources

Suppose an audit event records a new workload, runtime evidence later shows a credential file read, and network evidence shows contact with an unfamiliar destination. Correlate identifiers, timing and declared image or process behavior. Determine whether the records describe the same workload instance and whether another legitimate task could explain the sequence.

API audit may show a request's authenticated user, verb, resource and response status. Runtime sensors describe local operations. Application logs can explain the initiating input, while cloud identity logs may show later use of acquired credentials. Each source has collection, retention and tampering limits. An absent event can mean no action, missing collection or expired evidence; distinguish those possibilities.

## Contain Authority And Persistence

Deleting a suspicious Pod can stop current execution, but its controller may immediately recreate it. An altered Deployment template, CronJob or admission configuration can maintain the attacker's path. A stolen credential can remain usable after the original workload disappears. Containment should address the demonstrated execution mechanism, owner relationship and credential authority.

Preserve volatile evidence when feasible before disruptive changes, following the incident procedure and immediate risk. Restrict access to collected records because process arguments, payloads and request bodies can contain secrets or personal data. Record changes made during response so they are not mistaken for attacker activity.

## Define Recovery Evidence

Recovery includes removing the exploited path, revoking affected credentials, restoring trustworthy definitions and assessing data impact. A clean replacement image does not repair leaked credentials or corrupted external state. Confirm the intended workload behavior and monitoring coverage after restoration. Document what is known, what remains uncertain and which residual risks require follow-up rather than equate a quiet dashboard with complete recovery.

## Common pitfalls

> [!WARNING]
> A credential identity is not definitive human attribution. Pod deletion can leave controller persistence, stolen authority and data impact intact; timeline gaps must be represented honestly.
