def rules_text():
    return get('configmap', 'shell-in-probe-rule')['data'].get('rules.yaml', '')


if wants('rule-condition'):
    import re
    text = rules_text()
    assert '- rule:' in text and 'desc:' in text, 'rules.yaml must contain a rule with a description'
    condition_text = text.split('condition:', 1)[1].split('output:', 1)[0] if 'condition:' in text and 'output:' in text else ''
    assert condition_text, 'The rule needs a condition followed by an output'
    normalized = ' '.join(condition_text.replace('>', '').split())
    assert 'spawned_process' in normalized and 'container' in normalized, 'Match process creation inside containers'
    assert 'k8s.ns.name = starfleet-036-010-02-01' in normalized, 'Scope the rule to the starfleet-036-010-02-01 namespace'
    shell_names = re.search(r'proc\.name\s+in\s*\(([^)]+)\)', normalized)
    assert shell_names and {'sh', 'bash', 'ash'} <= {name.strip().strip("\"'") for name in shell_names.group(1).split(',')}, 'Match sh, bash and ash process names'

if wants('rule-output'):
    text = rules_text()
    output_text = text.split('output:', 1)[1].split('priority:', 1)[0] if 'output:' in text and 'priority:' in text else ''
    assert '%k8s.pod.name' in output_text and '%proc.cmdline' in output_text, 'Output must name the pod and the command line'
    assert 'priority: WARNING' in text, 'Use priority WARNING'
