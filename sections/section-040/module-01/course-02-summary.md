---
draft: true
exam_objectives:
- Ensure immutability of containers at runtime
---
# Summary

Runtime immutability keeps image content separate from justified writable data and favors reviewed replacement over ad hoc mutation. A read-only root filesystem constrains one write surface while dedicated volumes serve necessary state.

Identity, capabilities, host mounts and executable writable paths determine the remaining authority. Immutability supports detection and recovery, but does not prevent memory-only attacks, malicious use of credentials or corruption of permitted data.
