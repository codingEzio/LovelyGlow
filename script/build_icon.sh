#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Resources/LovelyGlow.svg"
# Public source packages exclude the unverified private mark.
if [[ ! -f "$SOURCE" ]]; then
    SOURCE="$ROOT_DIR/Resources/PublicIcon.svg"
fi
DESTINATION=""
if [[ $# -eq 2 && "$1" == "--output" && -n "$2" ]]; then
    DESTINATION="$2"
elif [[ $# -ne 0 ]]; then
    echo "usage: $0 [--output NEW_ICON_PATH]" >&2
    exit 2
fi

# Each invocation owns its own workspace. Standalone mode retains the resulting
# icon for its caller; --output saves it at the requested new destination.
ICON_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/lovelyglow-icon.XXXXXXXX")"
ICONSET_DIR="$ICON_DIR/LovelyGlow.iconset"
OUTPUT="$ICON_DIR/LovelyGlow.icns"
OUTPUT_STAGING=""

cleanup() {
    local status=$?
    trap - EXIT HUP INT TERM
    if [[ -n "$OUTPUT_STAGING" ]]; then
        /bin/rm -f -- "$OUTPUT_STAGING"
    fi
    if (( status != 0 )) || [[ -n "$DESTINATION" ]]; then
        /bin/rm -rf -- "$ICON_DIR"
    else
        /bin/rm -rf -- "$ICONSET_DIR"
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
/bin/mkdir -p "$ICONSET_DIR"

render() {
    local size="$1"
    local name="$2"
    if [[ -x /opt/homebrew/bin/rsvg-convert ]]; then
        /opt/homebrew/bin/rsvg-convert -w "$size" -h "$size" -o "$ICONSET_DIR/$name" "$SOURCE"
    else
        /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE" --out "$ICONSET_DIR/$name" >/dev/null
    fi
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

if ! /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT" 2>/dev/null; then
    /bin/rm -f "$OUTPUT"
    /usr/bin/python3 - "$ICONSET_DIR" "$OUTPUT" <<'PY'
import struct
import sys
from pathlib import Path

iconset = Path(sys.argv[1])
output = Path(sys.argv[2])
entries = {
    "icp4": "icon_16x16.png",
    "icp5": "icon_32x32.png",
    "ic11": "icon_16x16@2x.png",
    "ic12": "icon_32x32@2x.png",
    "ic07": "icon_128x128.png",
    "ic13": "icon_256x256.png",
    "ic08": "icon_256x256.png",
    "ic14": "icon_512x512.png",
    "ic09": "icon_512x512.png",
    "ic10": "icon_512x512@2x.png",
}
chunks = []
for kind, filename in entries.items():
    payload = (iconset / filename).read_bytes()
    chunks.append(kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload)
body = b"".join(chunks)
output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
PY
fi
if [[ -n "$DESTINATION" ]]; then
    # Stage beside the destination, then atomically link without overwriting an
    # existing path. The parent owns the staging file even when linking fails.
    OUTPUT_STAGING="$(/usr/bin/mktemp "$(/usr/bin/dirname "$DESTINATION")/.lovelyglow-icon.XXXXXXXX")"
    /bin/cp "$OUTPUT" "$OUTPUT_STAGING"
    /bin/chmod "$(/usr/bin/stat -f '%Lp' "$OUTPUT")" "$OUTPUT_STAGING"
    /usr/bin/python3 - "$OUTPUT_STAGING" "$DESTINATION" <<'PY'
import os
import sys
os.link(sys.argv[1], sys.argv[2])
PY
    printf '%s\n' "$DESTINATION"
else
    printf '%s\n' "$OUTPUT"
fi
