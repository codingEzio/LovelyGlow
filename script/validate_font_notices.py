#!/usr/bin/env python3
"""Require a readable, nonempty notices directory containing regular files."""
import os
from pathlib import Path
import stat
import sys


def valid(root):
    if root.is_symlink() or not root.is_dir():
        return False
    found = False
    def onerror(error):
        raise error

    for directory, dirs, files in os.walk(root, followlinks=False, onerror=onerror):
        for name in dirs:
            if (Path(directory) / name).is_symlink():
                return False
        for name in files:
            path = Path(directory) / name
            if path.is_symlink() or not stat.S_ISREG(path.stat().st_mode):
                return False
            with path.open('rb') as source:
                if source.read(1):
                    found = True
    return found


try:
    if len(sys.argv) != 2 or not valid(Path(sys.argv[1])):
        raise ValueError
except (OSError, ValueError):
    raise SystemExit('Private font notices are missing, empty, unreadable, or invalid.')
