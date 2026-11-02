---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Ensure immutability of containers at runtime

An application needs temporary files but does not need to rewrite its executable directory. A narrow writable volume can preserve its function while the image filesystem remains read-only.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Each module has a private playground where you run the commands, and one graded lab that practises the skill straight after the part that teaches it.

Read the module landing page, the deep-dive parts and the closing summary in order. A knowledge check of 10 questions follows the summary.

## Learning Outcomes

- Explain read-only root filesystems and their limits.
- Separate required temporary data from executable image content.
- Relate capabilities, identity and host mounts to immutability.
- Evaluate replacement-based updates and residual compromise paths.
