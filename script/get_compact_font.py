#!/usr/bin/env python3
"""Obtain or check LovelyGlow's pinned, separately distributed build input."""
import hashlib
import io
import os
from pathlib import Path
import stat
import sys
import secrets
import urllib.request
import urllib.error
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'Resources/Fonts/DeparturePixelZhCompact-Regular.ttf'
URL = 'https://github.com/codingEzio/DeparturePixelZh-OSS/releases/download/v0.1.1/DeparturePixelZh-0.1.1-desktop.zip'
ZIP_SHA = 'b050d6d71b3b79f947ffdd3f0fab2c4f1deb2cc77e9d32cf10942b7d09a265b8'
FONT_SHA = '3e75e623b1ba2c8d7eb52f2ac3ee71c3fbb5c4e0f1426bd34b3c1e071738288b'
FONT_SIZE = 4_975_088
MEMBER = 'DeparturePixelZh-0.1.1-desktop/DeparturePixelZhCompact-Regular.ttf'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def open_directory(create=False):
    """Open the final directory without following a symbolic link."""
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    try:
        return os.open(DEST.parent, flags)
    except FileNotFoundError:
        if not create:
            raise
        ancestor = os.open(DEST.parent.parent, flags)
        try:
            try:
                os.mkdir(DEST.parent.name, 0o777, dir_fd=ancestor)
            except FileExistsError:
                pass  # Validate the concurrent creator using a no-follow open.
            return os.open(DEST.parent.name, flags, dir_fd=ancestor)
        finally:
            os.close(ancestor)


def check_at(directory_fd):
    try:
        fd = os.open(DEST.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
    except FileNotFoundError:
        raise SystemExit('Compact font missing. Run: python3 script/get_compact_font.py')
    except OSError:
        raise SystemExit('Compact font is not an accessible regular file; existing path retained.')
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode):
            raise SystemExit('Compact font is not a regular file; existing path retained.')
        if info.st_size != FONT_SIZE or digest(source.read()) != FONT_SHA:
            raise SystemExit('Compact font SHA-256 mismatch; existing file retained.')


def check():
    try:
        directory_fd = open_directory()
    except FileNotFoundError:
        raise SystemExit('Compact font missing. Run: python3 script/get_compact_font.py')
    try:
        check_at(directory_fd)
    finally:
        os.close(directory_fd)


def obtain():
    try:
        directory_fd = open_directory()
    except FileNotFoundError:
        directory_fd = None
    if directory_fd is not None:
        try:
            try:
                os.stat(DEST.name, dir_fd=directory_fd, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                check_at(directory_fd)
                print('Pinned Compact font already present and verified.')
                return
        finally:
            os.close(directory_fd)
    request = urllib.request.Request(URL, headers={'User-Agent': 'LovelyGlow-source-setup'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            archive = response.read(50_000_001)
    except (urllib.error.URLError, TimeoutError, OSError):
        raise SystemExit('Compact font download failed. Check the network and retry; the destination was not changed.')
    if len(archive) > 50_000_000 or digest(archive) != ZIP_SHA:
        raise SystemExit('Desktop archive SHA-256 mismatch or size limit exceeded.')
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        info = z.getinfo(MEMBER)
        if info.file_size != FONT_SIZE:
            raise SystemExit('Unexpected Compact font size.')
        font = z.read(info)
    if digest(font) != FONT_SHA:
        raise SystemExit('Compact font SHA-256 mismatch.')
    directory_fd = open_directory(create=True)
    temporary = None
    try:
        for _ in range(16):
            name = '.compact-font-' + secrets.token_hex(16)
            try:
                fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=directory_fd)
                temporary = name
                break
            except FileExistsError:
                continue
        else:
            raise OSError('Temporary name allocation failed')
        with os.fdopen(fd, 'wb') as output:
            current_umask = os.umask(0)
            os.umask(current_umask)
            os.fchmod(output.fileno(), 0o666 & ~current_umask)
            output.write(font)
            output.flush()
            os.fsync(output.fileno())
        verify_fd = os.open(temporary, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory_fd)
        with os.fdopen(verify_fd, 'rb') as verify:
            if digest(verify.read()) != FONT_SHA:
                raise SystemExit('Temporary Compact font verification failed.')
        try:
            os.link(temporary, DEST.name, src_dir_fd=directory_fd, dst_dir_fd=directory_fd, follow_symlinks=False)
        except FileExistsError:
            # Accept a concurrent writer only when it published the same regular file.
            check_at(directory_fd)
        os.fsync(directory_fd)
    finally:
        try:
            if temporary is not None:
                os.unlink(temporary, dir_fd=directory_fd)
        finally:
            os.close(directory_fd)
    print('Pinned Compact font verified. Review its rights before redistribution.')


def main(args):
    if args == ['--check']:
        check()
    elif not args:
        obtain()
    else:
        raise SystemExit('Usage: python3 script/get_compact_font.py [--check]')


def cli():
    try:
        main(sys.argv[1:])
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit('Compact font download failed. Check the network and retry; the destination was not changed.')
    except (zipfile.BadZipFile, KeyError):
        raise SystemExit('Compact font archive is invalid or missing its expected entry; the destination was not changed.')
    except OSError:
        raise SystemExit('Compact font file operation failed. The destination may already exist; check it before retrying.')


if __name__ == '__main__':
    cli()
