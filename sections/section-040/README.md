---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Ensure immutability of containers at runtime

An application needs temporary files but does not need to rewrite its executable directory. A narrow writable volume can preserve its function while the image filesystem remains read-only.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Explain read-only root filesystems and their limits.
- Separate required temporary data from executable image content.
- Relate capabilities, identity and host mounts to immutability.
- Evaluate replacement-based updates and residual compromise paths.
