#!/usr/bin/env python3
"""Read local font selection as data; never evaluate it as shell code."""
import json
import os
import stat
from pathlib import Path
import sys


def fail():
    raise SystemExit('Invalid local font configuration or override.')


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail()
        result[key] = value
    return result


def path_value(value, base):
    if not isinstance(value, str) or not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
        fail()
    result = os.path.abspath(os.path.join(base, value))
    if any(ord(c) < 32 or ord(c) == 127 for c in result):
        fail()
    return result


def main():
    if len(sys.argv) != 2:
        fail()
    root = os.path.abspath(sys.argv[1])
    config_path = Path(root) / 'Local' / 'font-input.json'
    config = {}
    try:
        config_stat = config_path.lstat()
    except FileNotFoundError:
        config_stat = None
    if config_stat is not None:
        if not stat.S_ISREG(config_stat.st_mode) or config_stat.st_size > 16384:
            fail()
        config = json.loads(config_path.read_text(encoding='utf-8'), object_pairs_hook=unique_pairs)
        if not isinstance(config, dict) or set(config) - {'font', 'notices'} or 'font' not in config:
            fail()
        config = {key: path_value(value, root) for key, value in config.items()}
    font_override = os.environ.get('LOVELYGLOW_PRIVATE_FONT')
    notice_override = os.environ.get('LOVELYGLOW_PRIVATE_FONT_NOTICES')
    if font_override is not None:
        font = path_value(font_override, os.getcwd())
        notices = ''  # Never attach another font's configured notices to an override.
    else:
        font = config.get('font', '')
        notices = config.get('notices', '')
    if notice_override is not None:
        if not font:
            fail()
        notices = path_value(notice_override, os.getcwd())
    print(font)
    print(notices)
    print('.')


try:
    main()
except (OSError, UnicodeError, ValueError, TypeError):
    fail()
