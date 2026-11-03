---
draft: true
exam_objectives:
- Use Kubernetes audit logs to monitor access
---
# Forwarding And Retention Policy

A log file on one node is a single point of failure for evidence. The API server can also send events to a webhook backend, which is an HTTPS service that receives batches of events. This part describes the webhook flags and the trade-off between losing events and losing availability, and ends with the decisions that make up a retention policy.

## The webhook backend

The webhook backend is turned on with `--audit-webhook-config-file`, which points to a file in kubeconfig format. The `server` field of that file holds the URL of the collector, and the credentials are the client certificate or token in the same file. The API server posts events to that URL as a JSON list.

The main flags are:

| Flag | Meaning |
| --- | --- |
| `--audit-webhook-config-file` | Path to the kubeconfig-format file that names the collector. |
| `--audit-webhook-mode` | How events are sent: `batch`, `blocking` or `blocking-strict`. |
| `--audit-webhook-batch-max-size` | The largest number of events in one batch. |
| `--audit-webhook-batch-max-wait` | The longest time to wait before sending a batch. |
| `--audit-webhook-initial-backoff` | The first wait before a retry after a failed send. |

The same flags with the prefix `--audit-log-` exist for the log backend, for example `--audit-log-mode` and `--audit-log-format`. The flag `--audit-log-format` chooses `json` or the older `legacy` text format. Use `json` for any tool that parses events.

## The three modes

The mode decides what the API server does when sending is slow or fails:

| Mode | Behavior |
| --- | --- |
| `batch` | The API server buffers events and sends them in the background. A full buffer drops events. Requests are not delayed. |
| `blocking` | The API server sends events as part of each request. A slow collector slows every request. |
| `blocking-strict` | Like `blocking`, but a failed send at the `RequestReceived` stage makes the request fail. |

The choice is a trade-off. `batch` protects availability and can lose events under load. `blocking-strict` protects the log and can make the cluster unavailable when the collector is down. Many clusters use `batch` for the webhook and keep the local file as a second copy, so that a failure of one path does not erase everything.

## Decisions in a retention policy

A retention policy answers these questions with numbers:

- How long must events be available for an investigation? This sets the age of the oldest event, for example 90 days.
- How much storage does that need? Multiply the event rate by the period.
- Where does the long-term copy live, and who can delete it?
- How fast must a new event reach it, and what happens when the collector is down?

The flags on the node cover only the first few hours or days. Long-term retention belongs to the collector, with its own access controls and its own deletion rules. This part linked the flags to those decisions. A cluster is ready for investigation when the local limits cover the delay in finding an incident, and the remote copy covers the legal and operational period.

## Common pitfalls

> [!WARNING]
> - **Using `blocking-strict` without checking the collector.** A collector outage can stop API requests.
> - **Expecting `batch` to never lose events.** A full buffer drops them.
> - **Keeping the long-term copy under the same administrators.** Use separate access for the collector.
> - **Choosing the `legacy` format.** Parsing tools expect `json`.
