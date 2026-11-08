#!/usr/bin/env python3
"""Atomically rename on macOS only when the destination does not exist."""
import ctypes
import os
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: exclusive_move.py SOURCE DESTINATION")

libc = ctypes.CDLL(None, use_errno=True)
rename_exclusive = libc.renamex_np
rename_exclusive.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint)
rename_exclusive.restype = ctypes.c_int
if rename_exclusive(os.fsencode(sys.argv[1]), os.fsencode(sys.argv[2]), 0x00000004) != 0:
    error = ctypes.get_errno()
    raise OSError(error, os.strerror(error), sys.argv[2])
