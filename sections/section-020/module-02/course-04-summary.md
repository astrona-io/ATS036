---
draft: true
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Summary

Workloads leave evidence in three places that need no extra sensor. Kubernetes events record what the scheduler, the kubelet and the controllers did. The Pod specification records what a Pod is allowed to do. The container log records what the application chose to print. Each source answers a different question, and none of them answers all questions.

Events have a type, a reason, a message and a reporting component, and the API server removes them after one hour by default, so a cluster that needs them later must export them. A `Normal` event says that Kubernetes did its work, not that the Pod was safe. A privileged container, a `hostPath` volume, and the settings `hostNetwork`, `hostPID` and `hostIPC` give a container access to the node. Pod Security Admission rejects these settings at creation time when the namespace label selects the `baseline` or `restricted` level, and it does not check Pods that already exist.

An application log shows facts that only the application knows, such as failed logins. A count becomes a signal when its rate, time window and target differ from normal behavior, and the log supports that judgment only when it records time and source. The key facts to remember are these:

- Read the specification to learn what a Pod may do.
- Read events early, because they expire.
- Count with a precise pattern and a defined time window.
- A missing line or event is a gap in evidence, not proof of no activity.

<!-- astrona:playground:destroy -->
