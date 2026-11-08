"""Exercise font selection without installing or launching the application."""
import os
import json
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
        for name in ('font_input.sh', 'font_config.py', 'validate_font.swift', 'validate_font_notices.py', 'get_compact_font.py'):
            shutil.copy(ROOT / 'script' / name, self.root / 'script' / name)
        self.env = os.environ.copy()
        self.env.pop('LOVELYGLOW_PRIVATE_FONT', None)
        self.env.pop('LOVELYGLOW_PRIVATE_FONT_NOTICES', None)

    def tearDown(self):
        self.temp.cleanup()

    def run_selection(self, requirement='required'):
        command = 'source "$1/script/font_input.sh"; select_font "$1" "$2" || exit; if [[ -n "$LOVELYGLOW_SELECTED_FONT" ]]; then copy_selected_font "$1/output.ttf" && copy_font_notices "$1/Licenses"; fi'
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

    @unittest.skipUnless(SYSTEM_FONT.is_file(), 'macOS test font unavailable')
    def test_private_font_notices_are_paired_or_marked_absent(self):
        fixture = self.root / 'fixture.ttf'
        fixture.write_bytes(SYSTEM_FONT.read_bytes())
        self.env['LOVELYGLOW_PRIVATE_FONT'] = str(fixture)
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        licenses = self.root / 'Licenses'
        self.assertIn('no notices were supplied', (licenses / 'LOCAL-FONT.txt').read_text())
        self.assertFalse((licenses / 'NOTICE.md').exists())
        shutil.rmtree(licenses)
        notices = self.root / 'notices'
        notices.mkdir()
        (notices / 'notice.txt').write_text('Synthetic font notice')
        self.env['LOVELYGLOW_PRIVATE_FONT_NOTICES'] = str(notices)
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((licenses / 'PrivateFont' / 'notice.txt').read_text(), 'Synthetic font notice')
        self.assertFalse((licenses / 'NOTICE.md').exists())
        shutil.rmtree(licenses)
        (notices / 'notice.txt').unlink()
        self.assertNotEqual(self.run_selection().returncode, 0)
        self.env['LOVELYGLOW_PRIVATE_FONT_NOTICES'] = str(self.root / 'missing')
        self.assertNotEqual(self.run_selection().returncode, 0)
        (notices / 'link').symlink_to(fixture)
        self.env['LOVELYGLOW_PRIVATE_FONT_NOTICES'] = str(notices)
        self.assertNotEqual(self.run_selection().returncode, 0)
        self.env.pop('LOVELYGLOW_PRIVATE_FONT')
        self.assertNotEqual(self.run_selection('optional').returncode, 0)

    @unittest.skipUnless(SYSTEM_FONT.is_file(), 'macOS test font unavailable')
    def test_local_config_and_explicit_overrides(self):
        local = self.root / 'Local'
        local.mkdir()
        configured = local / 'font.ttf'
        configured.write_bytes(SYSTEM_FONT.read_bytes())
        notices = local / 'notices'
        notices.mkdir()
        (notices / 'notice.txt').write_text('Synthetic notice')
        (local / 'font-input.json').write_text(json.dumps({'font': 'Local/font.ttf', 'notices': 'Local/notices'}))
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'output.ttf').read_bytes(), configured.read_bytes())
        self.assertEqual((self.root / 'Licenses/PrivateFont/notice.txt').read_text(), 'Synthetic notice')
        shutil.rmtree(self.root / 'Licenses')
        # An explicit font must not inherit notices belonging to another font.
        self.env['LOVELYGLOW_PRIVATE_FONT'] = str(configured)
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('no notices were supplied', (self.root / 'Licenses/LOCAL-FONT.txt').read_text())
        shutil.rmtree(self.root / 'Licenses')
        self.env['LOVELYGLOW_PRIVATE_FONT_NOTICES'] = str(notices)
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'Licenses/PrivateFont/notice.txt').is_file())

    def test_invalid_local_config_is_not_ignored(self):
        local = self.root / 'Local'
        local.mkdir()
        config = local / 'font-input.json'
        for content in ('{}', '{', '{"font":""}', '{"font":"a", "font":"b"}',
                        '{"font":"a", "unknown":1}', '{"font":"a", "notices":null}'):
            config.write_text(content)
            self.assertNotEqual(self.run_selection('optional').returncode, 0)
        marker = self.root / 'shell-executed'
        config.write_text(json.dumps({'font': '$(touch ' + str(marker) + ')'}))
        self.assertNotEqual(self.run_selection().returncode, 0)
        self.assertFalse(marker.exists())
        config.unlink()
        config.symlink_to(local / 'missing')
        self.assertNotEqual(self.run_selection('optional').returncode, 0)

    def test_explicit_invalid_and_missing_inputs_fail(self):
        fixture = self.root / 'invalid.ttf'
        fixture.write_bytes(b'not a font')
        for path in (fixture, self.root / 'missing.ttf'):
            self.env['LOVELYGLOW_PRIVATE_FONT'] = str(path)
            self.assertNotEqual(self.run_selection().returncode, 0)
            self.assertFalse((self.root / 'output.ttf').exists())


if __name__ == '__main__':
    unittest.main()
