#!/usr/bin/env python3
"""Reject labs that break the exam-ready layout."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
LAB = 'sections/section-020/module-01/labs/lab-01'
VM_LAB = 'sections/section-010/module-02/labs/lab-02'
spec = importlib.util.spec_from_file_location('layout', Path(__file__).with_name('check-lab-layout.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LayoutTests(unittest.TestCase):
    """Each test breaks one rule in a copy of the course and expects the check to fail."""

    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.root = Path(work.name)
        shutil.copy(ROOT / 'astrona.yaml', self.root)
        shutil.copytree(ROOT / 'sections', self.root / 'sections')
        self.lab = self.root / LAB

    def config(self):
        return yaml.safe_load((self.lab / 'config.yaml').read_text())

    def save_config(self, config):
        (self.lab / 'config.yaml').write_text(yaml.safe_dump(config, sort_keys=False))

    def test_valid(self):
        module.validate(self.root)

    def test_testing_init_order(self):
        config = self.config()
        config['testing']['init'].reverse()
        self.save_config(config)
        with self.assertRaisesRegex(ValueError, 'testing.init'):
            module.validate(self.root)

    def test_edited_shared_file(self):
        with (self.lab / 'testing/check.py').open('a') as handle:
            handle.write('# local change\n')
        with self.assertRaisesRegex(ValueError, 'differs from scripts/ci/lab-files/check.py'):
            module.validate(self.root)

    def test_edited_wrapper(self):
        wrapper = next(self.lab.glob('validation/*.sh'))
        wrapper.write_text(wrapper.read_text().replace('"${outcome#validate-}"', 'previous-exit-code'))
        with self.assertRaisesRegex(ValueError, 'differs from scripts/ci/lab-files/validate-outcome.sh'):
            module.validate(self.root)

    def test_unlisted_grader(self):
        shutil.copy(next(self.lab.glob('validation/*.sh')), self.lab / 'validation/validate-extra.sh')
        with self.assertRaisesRegex(ValueError, 'validation/ files and config.yaml differ'):
            module.validate(self.root)

    def test_grader_without_points(self):
        config = self.config()
        del config['validation']['scripts'][0]['points']
        self.save_config(config)
        with self.assertRaisesRegex(ValueError, 'needs a description and points'):
            module.validate(self.root)

    def test_untagged_outcome(self):
        path = self.lab / 'testing/requirements.json'
        path.write_text(path.read_text().replace('"previous-log-evidence"', '"log-evidence"'))
        with self.assertRaisesRegex(ValueError, 'graded outcomes and config.yaml differ'):
            module.validate(self.root)

    def test_bare_namespace(self):
        path = self.lab / 'testing/requirements.json'
        text = path.read_text()
        namespace = module.json.loads(text)['namespace']
        path.write_text(text.replace(f'"{namespace}"', '"starfleet"'))
        with self.assertRaisesRegex(ValueError, 'namespace must end with'):
            module.validate(self.root)

    def test_missing_context_guard(self):
        (self.lab / 'validate.sh').write_text('#!/usr/bin/env bash\npython3 testing/check.py "$@"\n')
        with self.assertRaisesRegex(ValueError, 'context guard'):
            module.validate(self.root)

    def test_long_exam_time(self):
        question = self.lab / 'question.md'
        text = question.read_text()
        question.write_text(module.re.sub(r'Allow about \d+ minutes', 'Allow about 45 minutes', text))
        with self.assertRaisesRegex(ValueError, 'Allow about N minutes'):
            module.validate(self.root)

    def test_exam_scope_on_qemu_lab(self):
        path = self.root / 'astrona.yaml'
        text = path.read_text()
        line = f'path: {VM_LAB}\n'
        indent = text.split(line, 1)[0].rsplit('\n', 1)[1]
        path.write_text(text.replace(line, f'{line}{indent}examScope: cluster\n', 1))
        with self.assertRaisesRegex(ValueError, 'only kind labs fit the exam profile'):
            module.validate(self.root)

    def test_qemu_grader_name_must_match_file(self):
        directory = self.root / VM_LAB / 'validation'
        next(directory.glob('*.sh')).rename(directory / 'validate-renamed.sh')
        with self.assertRaisesRegex(ValueError, 'validation/ files and config.yaml differ'):
            module.validate(self.root)


if __name__ == '__main__':
    unittest.main()
