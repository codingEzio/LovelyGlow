import plistlib
from pathlib import Path
import tempfile
import unittest

from migrate_settings import BUNDLE_ID, migrate


class SettingsMigrationTests(unittest.TestCase):
    def test_durable_migration_repeat_and_conflict_keep_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "Old App.app"
            (app / "Contents").mkdir(parents=True)
            legacy = root / "Old checkout/Local"
            legacy.mkdir(parents=True)
            original = b'enabled = true\nlanguage = "zh-TW"\n'
            (legacy / "config.toml").write_bytes(original)
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": BUNDLE_ID, "LovelyGlowLocalRoot": str(legacy),
            }))
            support = root / "Application Support"
            destination = support / BUNDLE_ID / "config.toml"
            self.assertEqual(migrate(app, support, check=True)["status"], "ready")
            self.assertFalse(destination.exists())
            first = migrate(app, support)
            self.assertEqual(migrate(app, support)["sha256"], first["sha256"])
            self.assertEqual(destination.read_bytes(), original)
            self.assertEqual(destination.stat().st_mode & 0o777, 0o600)
            destination.write_bytes(b'enabled = false\n')
            with self.assertRaisesRegex(ValueError, "Conflicting"):
                migrate(app, support)
            self.assertEqual(destination.read_bytes(), b'enabled = false\n')
            self.assertEqual((legacy / "config.toml").read_bytes(), original)
            destination.unlink()
            destination.symlink_to(legacy / "config.toml")
            with self.assertRaisesRegex(ValueError, "link"):
                migrate(app, support)


if __name__ == "__main__":
    unittest.main()
