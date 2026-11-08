#!/usr/bin/env python3
"""Exercise failed-install recovery only against synthetic directories."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import os

INSTALL_SCRIPT = Path(__file__).with_name("install.sh")


class InstallRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="lovelyglow-recovery-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.stage = self.root / "staging"
        self.previous = self.root / "previous"
        self.stage.mkdir()
        self.previous.mkdir()
        self.app = self.root / "Applications" / "LovelyGlow.app"
        self.app.parent.mkdir()
        self.saved = self.previous / "LovelyGlow.app"

    def bundle(self, path, content):
        path.mkdir()
        (path / "marker").write_text(content)

    def recover(self, expected_id="", previous_saved=True):
        script = 'source "$1"; recover_failed_install "$2" "$3" "$4" "$5" "Failed LovelyGlow.app" "$6" "$7"'
        return subprocess.run(
            ["/bin/bash", "-c", script, "recovery-test", str(INSTALL_SCRIPT), str(self.app),
             str(self.saved), str(self.stage), str(self.previous), expected_id, str(int(previous_saved))],
            text=True, capture_output=True, timeout=10,
        )

    def identity(self, path):
        data = path.lstat()
        return f"{data.st_dev}:{data.st_ino}"

    def test_restores_previous_bundle_and_cleans_owned_roots(self):
        self.bundle(self.app, "candidate")
        self.bundle(self.saved, "previous")
        result = self.recover(self.identity(self.app))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.app / "marker").read_text(), "previous")
        self.assertFalse(self.stage.exists())
        self.assertFalse(self.previous.exists())

    def test_failed_move_aside_keeps_previous_bundle(self):
        self.bundle(self.app, "candidate")
        self.bundle(self.saved, "previous")
        self.bundle(self.stage / "Failed LovelyGlow.app", "collision")
        result = self.recover(self.identity(self.app))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.saved / "marker").read_text(), "previous")
        self.assertEqual((self.app / "marker").read_text(), "candidate")
        self.assertIn(str(self.previous), result.stderr)

    def test_failed_restore_keeps_previous_bundle(self):
        self.bundle(self.saved, "previous")
        self.app.parent.rmdir()
        result = self.recover()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.saved / "marker").read_text(), "previous")
        self.assertIn(str(self.previous), result.stderr)

    def test_first_install_failure_removes_only_owned_candidate(self):
        self.bundle(self.app, "candidate")
        result = self.recover(self.identity(self.app), previous_saved=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.app.exists())
        self.assertFalse(self.stage.exists())
        self.assertFalse(self.previous.exists())

    def test_destination_collision_is_not_removed(self):
        self.bundle(self.app, "unrelated")
        self.bundle(self.saved, "previous")
        result = self.recover()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.app / "marker").read_text(), "unrelated")
        self.assertEqual((self.saved / "marker").read_text(), "previous")

    def test_replaced_candidate_is_not_removed(self):
        self.bundle(self.app, "candidate")
        candidate_id = self.identity(self.app)
        self.app.rename(self.root / "old-candidate")
        self.bundle(self.app, "unrelated")
        self.bundle(self.saved, "previous")
        result = self.recover(candidate_id)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.app / "marker").read_text(), "unrelated")
        self.assertEqual((self.saved / "marker").read_text(), "previous")

    def test_missing_expected_previous_is_reported(self):
        result = self.recover()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.previous.exists())
        self.assertIn("recovery directories retained", result.stderr)

    def test_missing_previous_does_not_delete_candidate(self):
        self.bundle(self.app, "candidate")
        result = self.recover(self.identity(self.app))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.app / "marker").read_text(), "candidate")
        self.assertTrue(self.previous.exists())
        self.assertTrue(self.stage.exists())

    def test_exclusive_move_does_not_nest_or_replace_destination(self):
        source = self.root / "source.app"
        destination = self.root / "destination.app"
        self.bundle(source, "candidate")
        self.bundle(destination, "unrelated")
        result = subprocess.run(["/usr/bin/python3", str(INSTALL_SCRIPT.with_name("exclusive_move.py")),
                                 str(source), str(destination)], text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((source / "marker").read_text(), "candidate")
        self.assertEqual((destination / "marker").read_text(), "unrelated")
        self.assertEqual(len(list(destination.iterdir())), 1)

    def interrupted_install(self, point, existing):
        # Replace external signing/process/migration boundaries with synthetic
        # fixtures while exercising the actual install_app trap and renames.
        fake_root = self.root / "fake-source"
        (fake_root / "script").mkdir(parents=True)
        exclusive = INSTALL_SCRIPT.with_name("exclusive_move.py").read_text()
        exclusive = exclusive.replace(
            "if rename_exclusive(",
            """point = os.environ.get('TEST_INTERRUPT_POINT')
source, destination = sys.argv[1:]
if point == 'collision' and '/.lovelyglow.staging.' in source and '/Applications/' in destination:
    os.mkdir(destination)
    with open(os.path.join(destination, 'marker'), 'w') as marker:
        marker.write('unrelated')
if point == 'previous-swapped' and '/.lovelyglow.previous.' in destination:
    os.rename(source, source + '.other-owner')
    os.mkdir(source)
    with open(os.path.join(source, 'marker'), 'w') as marker:
        marker.write('unrelated')
if rename_exclusive(""",
        )
        exclusive += """
import signal
point = os.environ.get('TEST_INTERRUPT_POINT')
source, destination = sys.argv[1:]
if (point == 'previous' and '/.lovelyglow.previous.' in destination) or (point == 'candidate' and '/.lovelyglow.staging.' in source and '/Applications/' in destination):
    os.kill(os.getppid(), signal.SIGTERM)
"""
        (fake_root / "script" / "exclusive_move.py").write_text(exclusive)
        (fake_root / "script" / "migrate_settings.py").write_text("pass\n")
        built = self.root / "built.app"
        self.bundle(built, "candidate")
        if existing:
            self.bundle(self.app, "previous")
        if point == "lock":
            lock = self.app.parent / ".lovelyglow.install.lock"
            lock.mkdir()
            (lock / "marker").write_text("other-owner")
        script = r'''source "$1"
ROOT_DIR="$2"; BUILT_APP="$3"; APP_PARENT="$4"; APP_BUNDLE="$5"
APP_BUNDLE_NAME=LovelyGlow; EXECUTABLE_NAME=LovelyGlow; APP_BINARY="$APP_BUNDLE/Contents/MacOS/LovelyGlow"
verify_bundle() { return 0; }
designated_requirement() { echo synthetic; }
stop_installed_process() { return 0; }
release_package_lock() { return 0; }
install_app
'''
        env = dict(os.environ, TEST_INTERRUPT_POINT=point)
        return subprocess.run(["/bin/bash", "-c", script, "transition-test", str(INSTALL_SCRIPT),
                               str(fake_root), str(built), str(self.app.parent), str(self.app)],
                              text=True, capture_output=True, timeout=10, env=env)

    def test_signal_after_previous_rename_restores_previous(self):
        result = self.interrupted_install("previous", True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.app / "marker").read_text(), "previous")

    def test_signal_after_candidate_rename_restores_previous(self):
        result = self.interrupted_install("candidate", True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.app / "marker").read_text(), "previous")

    def test_signal_after_first_install_rename_removes_candidate(self):
        result = self.interrupted_install("candidate", False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.app.exists())

    def test_candidate_collision_preserves_unrelated_and_previous(self):
        result = self.interrupted_install("collision", True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.app / "marker").read_text(), "unrelated")
        previous = list(self.app.parent.glob(".lovelyglow.previous.*/LovelyGlow.app/marker"))
        self.assertEqual(len(previous), 1)
        self.assertEqual(previous[0].read_text(), "previous")
        self.assertIn("recovery directories retained", result.stderr)

    def test_swapped_previous_is_preserved_for_review(self):
        result = self.interrupted_install("previous-swapped", True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        previous = list(self.app.parent.glob(".lovelyglow.previous.*/LovelyGlow.app/marker"))
        self.assertEqual(len(previous), 1)
        self.assertEqual(previous[0].read_text(), "unrelated")
        self.assertEqual((self.app.parent / "LovelyGlow.app.other-owner" / "marker").read_text(), "previous")
        self.assertIn("previous bundle changed", result.stderr)

    def test_existing_lock_is_not_removed_or_overridden(self):
        result = self.interrupted_install("lock", True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.app / "marker").read_text(), "previous")
        self.assertEqual((self.app.parent / ".lovelyglow.install.lock" / "marker").read_text(), "other-owner")

    def test_successful_replacement_releases_lock(self):
        result = self.interrupted_install("none", True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.app / "marker").read_text(), "candidate")
        self.assertFalse((self.app.parent / ".lovelyglow.install.lock").exists())
        self.assertEqual(list(self.app.parent.glob(".lovelyglow.previous.*")), [])


if __name__ == "__main__":
    unittest.main()
