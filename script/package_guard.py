#!/usr/bin/env python3
"""Cooperative package guard; re-exec entry with a lock inherited by child processes."""
import fcntl
import os
from pathlib import Path
import re
import stat
import sys
import uuid

raw_root = sys.argv[1]
root = Path(raw_root).resolve()
program, args = sys.argv[2], sys.argv[3:]
local = root / "Local"
if local.is_symlink():
    raise SystemExit("unsafe Local")
local.mkdir(mode=0o700, exist_ok=True)
lock = local / ".lovelyglow-package.v2-lock"
guard = local / ".lovelyglow-package.lock"
prefix = "lovelyglow-package-v2:"
receipt_prefix = b"lovelyglow-package-v2-receipt:"

def marker():
    try:
        if not stat.S_ISLNK(os.lstat(guard).st_mode):
            raise SystemExit("unknown legacy lock")
        value = os.readlink(guard)
    except FileNotFoundError:
        return None
    if not re.fullmatch(prefix + r"[0-9a-f]{32}", value):
        raise SystemExit("unknown symlink lock")
    return value

inherited = os.environ.get("LOVELYGLOW_GUARD_FD")
token = os.environ.get("LOVELYGLOW_GUARD_TOKEN")
if program in ("--verify", "--release") and not (inherited and token):
    raise SystemExit("missing inherited lock capability")
if inherited and token:
    try:
        fd = int(inherited)
        a, b = os.fstat(fd), os.stat(lock, follow_symlinks=False)
        if not stat.S_ISREG(a.st_mode) or (a.st_dev, a.st_ino) != (b.st_dev, b.st_ino):
            raise SystemExit("invalid inherited lock")
        if marker() != token:
            raise SystemExit("invalid inherited marker")
    except (ValueError, OSError):
        raise SystemExit("invalid inherited lock")
else:
    try:
        fd = os.open(lock, os.O_RDWR | os.O_NOFOLLOW)
    except FileNotFoundError:
        # No receipt means even a v2-looking symlink is foreign: never claim it.
        if marker() is not None:
            raise SystemExit("lock marker has no ownership receipt")
        temporary = local / (".lovelyglow-package-init-" + uuid.uuid4().hex)
        initial = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            data = receipt_prefix + uuid.uuid4().hex.encode() + b"\n"
            offset = 0
            while offset < len(data):
                written = os.write(initial, data[offset:])
                if written == 0:
                    raise OSError("could not write ownership receipt")
                offset += written
            os.fsync(initial)
        finally:
            os.close(initial)
        try:
            try:
                os.link(temporary, lock, follow_symlinks=False)
            except FileExistsError:
                pass
            fd = os.open(lock, os.O_RDWR | os.O_NOFOLLOW)
        finally:
            os.unlink(temporary)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or (info.st_mode & 0o777) != 0o600:
        raise SystemExit("unknown lock receipt")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("another operation is active")
    os.lseek(fd, 0, os.SEEK_SET)
    receipt = os.read(fd, len(receipt_prefix) + 34)
    if not re.fullmatch(receipt_prefix + rb"[0-9a-f]{32}\n", receipt):
        raise SystemExit("unknown lock receipt")
    token = prefix + receipt[len(receipt_prefix):-1].decode()
    old_marker = marker()
    if old_marker is not None and old_marker != token:
        raise SystemExit("lock marker does not match receipt")
    if old_marker is not None:
        os.unlink(guard)
    try:
        os.symlink(token, guard)
    except FileExistsError:
        raise SystemExit("unknown legacy lock")
    os.set_inheritable(fd, True)
    os.environ["LOVELYGLOW_GUARD_FD"] = str(fd)
    os.environ["LOVELYGLOW_GUARD_TOKEN"] = token
    os.environ["LOVELYGLOW_GUARD_OWNER_PID"] = str(os.getpid())
    os.environ["LOVELYGLOW_GUARD_ROOT"] = raw_root

if program == '--verify':
    if not inherited or not token:
        raise SystemExit('no inherited lock')
    raise SystemExit(0)
if program == '--release':
    if not inherited or not token or marker() != token:
        raise SystemExit('not lock owner')
    if args != [os.environ.get('LOVELYGLOW_GUARD_OWNER_PID')]:
        raise SystemExit('not owner shell')
    os.unlink(guard)
    raise SystemExit(0)
os.execv(program, [program, *args])
