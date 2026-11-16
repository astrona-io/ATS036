import os
rules_text=get('configmap','shell-in-probe-rule')['data'].get('rules.yaml','')
assert '- rule:' in rules_text and 'desc:' in rules_text, 'rules.yaml must contain a rule with a description'
condition_text=rules_text.split('condition:',1)[1].split('output:',1)[0] if 'condition:' in rules_text and 'output:' in rules_text else ''
assert condition_text, 'The rule needs a condition followed by an output'
normalized=' '.join(condition_text.replace('>','').split())
assert 'spawned_process' in normalized and 'container' in normalized, 'Match process creation inside containers'
assert 'k8s.ns.name = starfleet' in normalized, 'Scope the rule to the starfleet namespace'
assert any(shell in normalized for shell in ('proc.name in (sh','proc.name = sh')), 'Match shell process names'
output_text=rules_text.split('output:',1)[1].split('priority:',1)[0] if 'priority:' in rules_text else ''
assert '%k8s.pod.name' in output_text and '%proc.cmdline' in output_text, 'Output must name the pod and the command line'
assert 'priority: WARNING' in rules_text, 'Use priority WARNING'
