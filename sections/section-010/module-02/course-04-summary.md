---
draft: true
exam_objectives:
- Perform behavioral analytics to detect malicious activities
---
# Summary

A detection rule states one suspicious behavior, the place where it applies and the text of the alert. In a Falco rule file, a rule has a name, a description, a condition, an output and a priority. A macro is a named piece of a condition, and a list is a named list of values. The condition is an expression over event fields such as the process name, the command line, the parent process and the namespace.

A good rule is narrow. It combines the creation of a process with the container scope, a namespace and a short list of process names. Each added test removes events that are not the target behavior. The output carries the pod, the process, the parent process and the command line so that triage can start from the alert alone. Values come from what the workload really runs, and Pod names are not used because they change.

Approved behavior needs an exception, not a disabled rule. An exception compares several fields at once, for example namespace, container, parent process and command line, so it excludes only the approved case. A rule is tested in three steps: validate the file, produce the behavior and check the alert, and produce the normal behavior and check that it stays quiet.

A process rule sees only process creation. It does not see file reads, network connections or API calls made by a process that already runs, and it detects nothing on a node where the sensor is not running. A rule file in a ConfigMap is only stored text until the sensor loads it. The key facts to remember are these:

- A rule has a condition, an output and a priority.
- Scope a rule with the container macro, a namespace and specific process names.
- Tune with a narrow exception, not by disabling the rule.
- A rule that has never been tested has not been shown to work.



## Independent live assessment

Prepare with [Test A Live Sensor In A Linux VM](course-03a-test-a-live-sensor-in-a-linux-vm.md). [Test A Falco Rule Against Live Processes](labs/lab-02/question.md) uses its own qemu environment. Prove live shell detection and a narrow exception with real kernel events.. [Report And Contain Suspicious Behavior From Audit Evidence](labs/lab-01/question.md) uses its own kind environment. Report a denied Secret request and an exec from the audit log, then quarantine the Pod without deleting it..

<!-- astrona:playground:destroy -->
