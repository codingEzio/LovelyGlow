#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/script/product_config.sh"
load_product_config "$ROOT_DIR/config/product.conf"
# shellcheck disable=SC1091
source "$ROOT_DIR/script/package_lock.sh"

BUILD_DIR="$ROOT_DIR/Local/build-scratch"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FONTS="$APP_RESOURCES/Fonts"
APP_LICENSES="$APP_RESOURCES/Licenses"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

if [[ -d /Applications/Xcode-27-beta-6.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-27-beta-6.app/Contents/Developer
fi

usage() {
    echo "usage: $0 [run|--stage|--package|--verify]" >&2
}

process_ids_for_path() {
    local path="$1"
    /bin/ps -axo pid=,command= | /usr/bin/awk \
        -v expected="$path" -v self="$$" '$1 != self && $2 == expected { print $1 }'
}

verify_bundle() {
    local bundle="$1"
    [[ -d "$bundle" ]] || {
        echo "Missing app bundle: $bundle" >&2
        return 1
    }
    [[ -x "$bundle/Contents/MacOS/$EXECUTABLE_NAME" ]] || {
        echo "Missing app executable: $bundle/Contents/MacOS/$EXECUTABLE_NAME" >&2
        return 1
    }
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle" >/dev/null
    /usr/bin/plutil -lint "$bundle/Contents/Info.plist" >/dev/null
    [[ -f "$bundle/Contents/Resources/LovelyGlow.icns" ]] || {
        echo "Bundle icon is missing: $bundle/Contents/Resources/LovelyGlow.icns" >&2
        return 1
    }
    [[ -f "$bundle/Contents/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf" ]] || {
        echo "Compact font is missing: $bundle/Contents/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf" >&2
        return 1
    }
    [[ -f "$bundle/Contents/Resources/Licenses/OFL.txt" &&
        -f "$bundle/Contents/Resources/Licenses/NOTICE.md" &&
        -f "$bundle/Contents/Resources/Licenses/provenance.json" &&
        -d "$bundle/Contents/Resources/Licenses/licenses" ]] || {
        echo "Compact font notices are incomplete: $bundle" >&2
        return 1
    }
    [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$bundle/Contents/Info.plist")" == "$BUNDLE_ID" ]] || {
        echo "Bundle identifier mismatch: $bundle" >&2
        return 1
    }
    [[ "$(/usr/bin/plutil -extract CFBundleExecutable raw "$bundle/Contents/Info.plist")" == "$EXECUTABLE_NAME" ]] || {
        echo "Bundle executable mismatch: $bundle" >&2
        return 1
    }
}

build_candidate() {
    /usr/bin/python3 "$ROOT_DIR/script/get_compact_font.py" --check
    /bin/rm -rf -- "$APP_BUNDLE"
    /bin/mkdir -p "$BUILD_DIR" "$APP_MACOS" "$APP_FONTS" "$APP_LICENSES"

    cd "$ROOT_DIR"
    /usr/bin/swift build --jobs 2 --configuration release --scratch-path "$BUILD_DIR" --product "$EXECUTABLE_NAME"
    local build_binary
    build_binary="$(/usr/bin/swift build --configuration release --scratch-path "$BUILD_DIR" --show-bin-path)/$EXECUTABLE_NAME"
    [[ -x "$build_binary" ]] || {
        echo "Built executable is missing: $build_binary" >&2
        return 1
    }

    /bin/cp "$build_binary" "$APP_BINARY"
    /bin/chmod +x "$APP_BINARY"

    "$ROOT_DIR/script/build_icon.sh" --output "$APP_RESOURCES/LovelyGlow.icns" >/dev/null
    /bin/cp "$ROOT_DIR/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf" "$APP_FONTS/"
    /usr/bin/ditto "$ROOT_DIR/Resources/Licenses/" "$APP_LICENSES/"

    /usr/bin/plutil -create xml1 "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleDisplayName -string "$DISPLAY_NAME" "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleExecutable -string "$EXECUTABLE_NAME" "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleName -string "$PROJECT_NAME" "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundlePackageType -string APPL "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleShortVersionString -string "$VERSION" "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$INFO_PLIST"
    /usr/bin/plutil -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$INFO_PLIST"
    /usr/bin/plutil -insert LSUIElement -bool true "$INFO_PLIST"
    /usr/bin/plutil -insert NSHighResolutionCapable -bool true "$INFO_PLIST"
    /usr/bin/plutil -insert CFBundleIconFile -string LovelyGlow.icns "$INFO_PLIST"
    /usr/bin/plutil -insert NSPrincipalClass -string NSApplication "$INFO_PLIST"

    if ! /usr/bin/security find-identity -p codesigning -v | /usr/bin/grep -Fq "\"$SIGNING_IDENTITY\""; then
        echo "Missing code-signing identity: $SIGNING_IDENTITY" >&2
        return 1
    fi
    /usr/bin/codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE" >/dev/null
    verify_bundle "$APP_BUNDLE"
}

open_candidate_if_needed() {
    if [[ -z "$(process_ids_for_path "$APP_BINARY")" ]]; then
        /usr/bin/open -n "$APP_BUNDLE"
    fi
}

case "$MODE" in
    --stage|stage|--package|package|run|--verify|verify) ;;
    *) usage; exit 2 ;;
esac

if [[ -n "${LOVELYGLOW_GUARD_FD:-}" && "${LOVELYGLOW_GUARD_ROOT:-}" != "$ROOT_DIR" ]]; then
    unset LOVELYGLOW_GUARD_FD LOVELYGLOW_GUARD_TOKEN LOVELYGLOW_GUARD_OWNER_PID LOVELYGLOW_GUARD_ROOT
fi
if [[ -z "${LOVELYGLOW_GUARD_FD:-}" ]]; then
    exec /usr/bin/python3 "$ROOT_DIR/script/package_guard.py" "$ROOT_DIR" /bin/bash "$0" "$@"
fi
acquire_package_lock
cleanup_package_lock() {
    local status=$?
    trap - EXIT HUP INT TERM
    release_package_lock || { (( status != 0 )) || status=1; }
    exit "$status"
}
trap cleanup_package_lock EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

case "$MODE" in
    --stage|stage|--package|package)
        build_candidate
        echo "Staged $APP_BUNDLE"
        ;;
    run)
        build_candidate
        open_candidate_if_needed
        ;;
    --verify|verify)
        build_candidate
        open_candidate_if_needed
        /bin/sleep 1
        [[ -n "$(process_ids_for_path "$APP_BINARY")" ]] || {
            echo "Lovely Glow candidate did not start: $APP_BINARY" >&2
            exit 1
        }
        echo "Verified running $APP_BUNDLE"
        ;;
esac
