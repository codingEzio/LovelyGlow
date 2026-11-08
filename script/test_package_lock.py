#!/usr/bin/env python3
"""Exercise cooperative package ownership and interruption in synthetic checkouts."""
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parent


class PackageLockTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='lovelyglow-package-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'checkout'
        (self.root / 'script').mkdir(parents=True)
        for name in ('package_guard.py', 'package_lock.sh'):
            shutil.copyfile(SCRIPT / name, self.root / 'script' / name)
        self.guard = self.root / 'script/package_guard.py'
        self.lock = self.root / 'Local/.lovelyglow-package.lock'
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('LOVELYGLOW_GUARD_')}

    def command(self, shell, root=None):
        root = root or self.root
        return [sys.executable, str(root / 'script/package_guard.py'), str(root),
                '/bin/bash', '-c', shell, 'package-test', str(root)]

    def run_guard(self, shell, root=None):
        return subprocess.run(self.command(shell, root), capture_output=True, text=True,
                              timeout=10, env=self.env)

    def start_guard(self, shell):
        return subprocess.Popen(self.command(shell), text=True, stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                start_new_session=True, env=self.env)

    def read_line(self, process):
        self.assertTrue(select.select([process.stdout], [], [], 10)[0], 'lock owner timed out')
        return process.stdout.readline().strip()

    def close_process(self, process):
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=10)
        for stream in (process.stdin, process.stdout, process.stderr):
            stream.close()

    def test_nested_stage_cannot_release_parent_and_old_client_is_excluded(self):
        code = r'''ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock
/bin/bash -c 'ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock; release_package_lock' child "$ROOT_DIR" || exit 3
echo ready
read -r unused
release_package_lock'''
        p = self.start_guard(code)
        try:
            self.assertEqual(self.read_line(p), 'ready')
            self.assertNotEqual(self.run_guard('exit 0').returncode, 0)
            self.assertNotEqual(subprocess.run(['/bin/mkdir', str(self.lock)], capture_output=True).returncode, 0)
            p.stdin.write('finish\n'); p.stdin.flush()
            self.assertEqual(p.wait(timeout=10), 0, p.stderr.read())
            self.assertFalse(self.lock.exists() or self.lock.is_symlink())
            self.assertEqual(subprocess.run(['/bin/mkdir', str(self.lock)], capture_output=True).returncode, 0)
        finally:
            self.close_process(p)

    def test_unknown_legacy_and_v2_shaped_symlink_are_preserved(self):
        self.lock.mkdir(parents=True)
        (self.lock / 'foreign').write_text('preserve')
        self.assertNotEqual(self.run_guard('exit 0').returncode, 0)
        self.assertEqual((self.lock / 'foreign').read_text(), 'preserve')
        (self.lock / 'foreign').unlink(); self.lock.rmdir()
        foreign = 'lovelyglow-package-v2:' + ('a' * 32)
        os.symlink(foreign, self.lock)
        self.assertNotEqual(self.run_guard('exit 0').returncode, 0)
        self.assertEqual(os.readlink(self.lock), foreign)
        receipt = self.root / 'Local/.lovelyglow-package.v2-lock'
        self.assertFalse(receipt.exists(), 'unknown marker must not create a receipt')
        receipt.write_text('unknown receipt')
        receipt.chmod(0o600)
        self.assertNotEqual(self.run_guard('exit 0').returncode, 0)
        self.assertEqual(receipt.read_text(), 'unknown receipt')
        self.assertEqual(os.readlink(self.lock), foreign)

    def test_hard_kill_of_process_group_can_retry(self):
        p = self.start_guard('echo ready; read -r unused')
        try:
            self.assertEqual(self.read_line(p), 'ready')
            os.killpg(p.pid, signal.SIGKILL); p.wait(timeout=10)
            deadline = time.monotonic() + 5
            while True:
                r = self.run_guard('ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock; release_package_lock')
                if r.returncode == 0:
                    break
                if time.monotonic() >= deadline:
                    self.fail('guard not released after process-group exit: ' + r.stderr)
                time.sleep(0.02)
            self.assertFalse(self.lock.exists() or self.lock.is_symlink())
        finally:
            self.close_process(p)

    def test_term_cleanup_releases_owned_guard(self):
        code = r'''ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock
cleanup() { status=$?; trap - EXIT TERM; release_package_lock || status=1; exit "$status"; }
trap cleanup EXIT; trap 'exit 143' TERM
echo ready
read -r unused'''
        p = self.start_guard(code)
        try:
            self.assertEqual(self.read_line(p), 'ready')
            p.send_signal(signal.SIGTERM)
            self.assertNotEqual(p.wait(timeout=10), 0)
            self.assertFalse(self.lock.exists() or self.lock.is_symlink())
        finally:
            self.close_process(p)

    def test_hard_killed_parent_keeps_lock_until_surviving_child_exits(self):
        p = self.start_guard('/bin/sleep 30 & echo "$!"; wait')
        child = None
        try:
            child = int(self.read_line(p))
            p.kill(); p.wait(timeout=10)
            self.assertNotEqual(self.run_guard('exit 0').returncode, 0)
            os.kill(child, signal.SIGTERM)
            child = None
            deadline = time.monotonic() + 5
            while True:
                r = self.run_guard('ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock; release_package_lock')
                if r.returncode == 0:
                    break
                if time.monotonic() >= deadline:
                    self.fail('guard not released after child exit')
                time.sleep(0.02)
        finally:
            if child is not None:
                os.kill(child, signal.SIGKILL)
            self.close_process(p)

    def test_independent_checkouts_do_not_share_lock(self):
        other = Path(self.temp.name) / 'other'
        (other / 'script').mkdir(parents=True)
        for name in ('package_guard.py', 'package_lock.sh'):
            shutil.copyfile(SCRIPT / name, other / 'script' / name)
        p = self.start_guard('echo ready; read -r unused')
        try:
            self.assertEqual(self.read_line(p), 'ready')
            r = self.run_guard('ROOT_DIR="$1"; source "$ROOT_DIR/script/package_lock.sh"; acquire_package_lock; release_package_lock', other)
            self.assertEqual(r.returncode, 0, r.stderr)
            p.stdin.write('finish\n'); p.stdin.flush(); p.wait(timeout=10)
        finally:
            self.close_process(p)


if __name__ == '__main__':
    unittest.main()
