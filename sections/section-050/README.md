---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Use Kubernetes audit logs to monitor access

An audit response shows that a Pod creation was accepted, but no record proves the container ever started. API auditing and runtime observation describe different events.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Explain what Kubernetes audit events record.
- Compare Metadata, Request and RequestResponse audit detail.
- Relate audit retention and protection to investigation.
- Distinguish API evidence from runtime and application evidence.
