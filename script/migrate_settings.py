#!/usr/bin/env python3
"""Preserve legacy installed settings before switching to Application Support.

Called only after bundle identity/signature checks by install.sh. A conflicting
destination is never overwritten. The legacy source remains for owner recovery.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import tempfile

BUNDLE_ID = "com.alex.LovelyGlow"


def migrate(installed_app, support=None, check=False):
    info = plistlib.loads((Path(installed_app) / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise ValueError("Installed product identity differs")
    configured = info.get("LovelyGlowLocalRoot")
    if not configured:
        return {"status": "no-legacy-route", "check_only": check}
    if not isinstance(configured, str) or not Path(configured).is_absolute():
        raise ValueError("Legacy settings root is not an absolute path")
    source = Path(configured) / "config.toml"
    destination = (support or Path.home() / "Library/Application Support") / BUNDLE_ID / "config.toml"
    if source.is_symlink() or destination.is_symlink() or destination.parent.is_symlink():
        raise ValueError("Settings link requires owner review")
    if not source.exists():
        return {"status": "no-legacy-file", "check_only": check}
    if not source.is_file() or source.stat().st_size > 1024 * 1024:
        raise ValueError("Legacy settings file is not a bounded regular file")
    data = source.read_bytes()
    data.decode("utf-8")
    if destination.exists() and (not destination.is_file() or destination.read_bytes() != data):
        raise ValueError("Conflicting Application Support settings; neither file changed")
    if not check and not destination.exists():
        destination.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(prefix=".settings-", dir=destination.parent)
        try:
            with os.fdopen(descriptor, "wb") as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            # link is an atomic create-if-absent; a concurrent destination wins.
            try:
                os.link(temporary, destination)
            except FileExistsError:
                if destination.is_symlink() or destination.read_bytes() != data:
                    raise ValueError("Concurrent settings differ; source retained") from None
        finally:
            Path(temporary).unlink(missing_ok=True)
    if not check and destination.read_bytes() != data:
        raise ValueError("Migrated settings readback differs; source retained")
    return {"status": "verified" if not check else "ready", "check_only": check,
            "sha256": hashlib.sha256(data).hexdigest(), "source_retained": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("installed_app", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(migrate(args.installed_app, check=args.check)))
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")
