"""Exercise font selection without installing or launching the application."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SYSTEM_FONT = Path('/System/Library/Fonts/Geneva.ttf')


class FontInputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='lovelyglow-font-test-')
        self.root = Path(self.temp.name)
        (self.root / 'script').mkdir()
        for name in ('font_input.sh', 'validate_font.swift', 'get_compact_font.py'):
            shutil.copy(ROOT / 'script' / name, self.root / 'script' / name)
        self.env = os.environ.copy()
        self.env.pop('LOVELYGLOW_PRIVATE_FONT', None)

    def tearDown(self):
        self.temp.cleanup()

    def run_selection(self, requirement='required'):
        command = 'source "$1/script/font_input.sh"; select_font "$1" "$2" || exit; if [[ -n "$LOVELYGLOW_SELECTED_FONT" ]]; then copy_selected_font "$1/output.ttf"; fi'
        return subprocess.run(['/bin/bash', '-c', command, 'font-test', str(self.root), requirement],
                              env=self.env, capture_output=True, text=True)

    def test_missing_pinned_input_required_and_optional(self):
        self.assertNotEqual(self.run_selection().returncode, 0)
        self.assertEqual(self.run_selection('optional').returncode, 0)
        self.assertFalse((self.root / 'output.ttf').exists())

    @unittest.skipUnless(SYSTEM_FONT.is_file(), 'macOS test font unavailable')
    def test_explicit_valid_font_is_bundled_unchanged(self):
        fixture = self.root / 'fixture.ttf'
        fixture.write_bytes(SYSTEM_FONT.read_bytes())
        self.env['LOVELYGLOW_PRIVATE_FONT'] = str(fixture)
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'output.ttf').read_bytes(), fixture.read_bytes())

    def test_explicit_invalid_and_missing_inputs_fail(self):
        fixture = self.root / 'invalid.ttf'
        fixture.write_bytes(b'not a font')
        for path in (fixture, self.root / 'missing.ttf'):
            self.env['LOVELYGLOW_PRIVATE_FONT'] = str(path)
            self.assertNotEqual(self.run_selection().returncode, 0)
            self.assertFalse((self.root / 'output.ttf').exists())


if __name__ == '__main__':
    unittest.main()
