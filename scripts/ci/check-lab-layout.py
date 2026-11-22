#!/usr/bin/env python3
"""Check the exam-ready layout of every registered lab.

The rules are the ATS034 ones (CLAUDE.md, "Exam-ready labs"):

- testing.init is verify-start, the reference solution, wait-solved;
- validation.scripts lists one grader per outcome, each with a description
  and points, and each validation/validate-<outcome>.sh is the shared wrapper;
- the shared files in testing/ equal scripts/ci/lab-files;
- the outcomes tagged in requirements.json and named in live.py equal the
  graders in config.yaml;
- the namespace, context and cluster name the lab;
- validate.sh and solution/apply.sh keep the context guard;
- question.md states an exam time of at most 20 minutes;
- examScope appears only on kind labs;
- a qemu lab uses the generated vm/ scripts and they are not stale.

check-course-structure.py checks registration, links and task counts.
"""
from pathlib import Path
import importlib.util
import json
import re
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
SHARED = Path(__file__).resolve().parent / 'lab-files'
SHARED_FILES = {
    'testing/check.py': 'check.py',
    'testing/verify-start.sh': 'verify-start.sh',
    'testing/wait-solved.sh': 'wait-solved.sh',
}
LIFECYCLE = ['testing/verify-start.sh', 'solution/apply.sh', 'testing/wait-solved.sh']
VM_LIFECYCLE = ['vm/verify-start.sh', 'vm/apply-solution.sh', 'vm/wait-solved.sh']
# qemu labs that still build their own cluster inside a plain Ubuntu VM (kind
# in the VM, or Falco on the host) and grade with their own checker. They are
# checked for one grader per outcome only, until they move to the kubeadm
# layout that scripts/ci/vm-lab.py generates.
OWN_VM_LAYOUT = {
    'sections/section-010/module-02/labs/lab-02',
    'sections/section-010/module-02/labs/lab-03',
    'sections/section-050/module-03/labs/lab-02',
}
spec = importlib.util.spec_from_file_location('vm_lab', Path(__file__).with_name('vm-lab.py'))
vm_lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm_lab)
MAX_MINUTES = 20


def lab_suffix(name):
    match = re.fullmatch(r'ats-036-lab-(\d{3})-(\d{2})-(\d{2})', name)
    if not match:
        raise ValueError(f'{name}: lab name must be ats-036-lab-<section>-<module>-<lab>')
    return '036-' + '-'.join(match.groups())


def check_graders(lab, directory, scripts, qemu):
    if not scripts:
        raise ValueError(f'{lab}: validation needs one scripts entry per outcome')
    for grader in scripts:
        if not grader.get('description') or not isinstance(grader.get('points'), int):
            raise ValueError(f'{lab}: grader {grader.get("name")} needs a description and points')
        source = f'{"vm" if qemu else "validation"}/validate-{grader["name"]}.sh'
        if grader['source'] != source:
            raise ValueError(f'{lab}: grader {grader["name"]} must use {source}')
    listed = {f'validation/validate-{grader["name"]}.sh' for grader in scripts}
    present = {str(path.relative_to(directory)) for path in directory.glob('validation/*')}
    if listed != present:
        raise ValueError(f'{lab}: validation/ files and config.yaml differ: {sorted(listed ^ present)}')


def check_lab(root, lab, entry):
    directory = root / lab
    cfg = yaml.safe_load((directory / 'config.yaml').read_text())
    name = cfg['metadata']['name']
    suffix = lab_suffix(name)
    runtime = cfg['runtime']['type']
    qemu = runtime == 'qemu'
    scripts = (cfg.get('validation') or {}).get('scripts', [])
    if entry.get('examScope') and runtime != 'kind':
        raise ValueError(f'{lab}: only kind labs fit the exam profile')
    if lab in OWN_VM_LAYOUT:
        check_graders(lab, directory, scripts, False)
        return name
    init = [item.get('source') for item in cfg.get('testing', {}).get('init', [])]
    lifecycle = VM_LIFECYCLE if qemu else LIFECYCLE
    if init != lifecycle:
        raise ValueError(f'{lab}: testing.init must be {lifecycle}')
    check_graders(lab, directory, scripts, qemu)
    wrapper = (SHARED / 'validate-outcome.sh').read_bytes()
    for grader in scripts:
        if (directory / f'validation/validate-{grader["name"]}.sh').read_bytes() != wrapper:
            raise ValueError(f'{lab}: validation/validate-{grader["name"]}.sh differs from scripts/ci/lab-files/validate-outcome.sh')
    shared_files = {**SHARED_FILES, 'bootstrap/helpers.sh': 'vm-helpers.sh'} if qemu else SHARED_FILES
    for path, shared in shared_files.items():
        if (directory / path).read_bytes() != (SHARED / shared).read_bytes():
            raise ValueError(f'{lab}: {path} differs from scripts/ci/lab-files/{shared}')
    if qemu and [item.get('source') for item in cfg.get('bootstrap', {}).get('init', [])] != ['vm/install.sh']:
        raise ValueError(f'{lab}: bootstrap.init of a qemu lab must be vm/install.sh')
    requirements = json.loads((directory / 'testing/requirements.json').read_text())
    outcomes = {grader['name'] for grader in scripts}
    tagged = {item['outcome'] for key in ('resources', 'behavior') for item in requirements.get(key, []) if 'outcome' in item}
    live = directory / 'testing/live.py'
    computed = False
    if live.exists():
        text = live.read_text()
        tagged |= set(re.findall(r"wants\('([\w-]+)'\)", text))
        # wants(prefix + name) names outcomes at run time; only literal names can be compared.
        computed = bool(re.search(r"wants\((?!')", text))
    if not tagged <= outcomes or (not computed and tagged != outcomes):
        raise ValueError(f'{lab}: graded outcomes and config.yaml differ: {sorted(tagged ^ outcomes)}')
    if not requirements['namespace'].endswith('-' + suffix):
        raise ValueError(f'{lab}: namespace must end with -{suffix}')
    if runtime == 'kind' and (requirements['context'], requirements['cluster']) != (f'kind-astro-{name}', f'astro-{name}'):
        raise ValueError(f'{lab}: requirements.json context and cluster must name astro-{name}')
    vm_requirements = (f'kubernetes-admin@astro-{name}', f'astro-{name}', 'qemu')
    if qemu and (requirements['context'], requirements['cluster'], requirements.get('runtime')) != vm_requirements:
        raise ValueError(f'{lab}: requirements.json of a qemu lab must be context, cluster and runtime {vm_requirements}')
    for script in ['validate.sh', 'solution/apply.sh']:
        if 'ASTRONA_KUBE_CONTEXT' not in (directory / script).read_text():
            raise ValueError(f'{lab}: {script} needs the context guard')
    question = (directory / 'question.md').read_text()
    minutes = re.search(r'^Allow about (\d+) minutes for the tasks\.$', question, re.M)
    if not minutes or int(minutes.group(1)) > MAX_MINUTES:
        raise ValueError(f'{lab}: question.md needs "Allow about N minutes for the tasks." with N <= {MAX_MINUTES}')
    # Last, so a broken source file reports its own rule first.
    if qemu and vm_lab.stale(directory):
        raise ValueError(f'{lab}: stale {vm_lab.stale(directory)}; run python3 scripts/ci/vm-lab.py {lab}')
    return name


def validate(root):
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    labs = {entry['path']: entry for module in course['modules'] for entry in module.get('content', []) if entry['type'] == 'lab'}
    errors = []
    for lab, entry in labs.items():
        try:
            check_lab(root, lab, entry)
        except (ValueError, KeyError, OSError) as error:
            errors.append(str(error))
    if errors:
        raise ValueError('\n  '.join([f'{len(errors)} labs fail:'] + errors))
    return len(labs)


if __name__ == '__main__':
    try:
        count = validate(ROOT)
        print(f'PASS: {count} labs have the exam-ready layout ({len(OWN_VM_LAYOUT)} qemu labs keep their own VM layout)')
    except (ValueError, KeyError, OSError) as error:
        sys.exit(f'FAIL: {error}')
