#!/usr/bin/env bash
# Separate, ad-hoc signed development bundle; never touches the installed app.
set -euo pipefail
umask 077
mode="${1:---run}"
if [[ $# -gt 1 || ( "$mode" != "--build" && "$mode" != "--run" ) ]]; then
    echo "usage: $0 [--build|--run]" >&2
    exit 2
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$root/Local"
work="$(mktemp -d "$root/Local/lovelyglow-dev.XXXXXXXX")"
app="$work/LovelyGlow Dev.app"
contents="$app/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources"
cd "$root"
/usr/bin/swift build --jobs 2 --configuration release --scratch-path "$root/Local/swift-dev-build" --product LovelyGlow
binary="$(/usr/bin/swift build --configuration release --scratch-path "$root/Local/swift-dev-build" --show-bin-path)/LovelyGlow"
cp "$binary" "$contents/MacOS/LovelyGlow"
source "$root/script/font_input.sh"
select_font "$root" optional
copy_font_notices "$contents/Resources/Licenses"
if [[ -n "$LOVELYGLOW_SELECTED_FONT" ]]; then
    mkdir "$contents/Resources/Fonts"
    copy_selected_font "$contents/Resources/Fonts/DeparturePixelZhCompact-Regular.ttf"
fi
plist="$contents/Info.plist"
/usr/bin/plutil -create xml1 "$plist"
/usr/bin/plutil -insert CFBundleDisplayName -string 'Lovely Glow Dev' "$plist"
/usr/bin/plutil -insert CFBundleName -string 'Lovely Glow Dev' "$plist"
/usr/bin/plutil -insert CFBundleExecutable -string LovelyGlow "$plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.github.codingEzio.LovelyGlow.Development "$plist"
/usr/bin/plutil -insert CFBundlePackageType -string APPL "$plist"
/usr/bin/plutil -insert CFBundleShortVersionString -string 0.7.9 "$plist"
/usr/bin/plutil -insert CFBundleVersion -string 33 "$plist"
/usr/bin/plutil -insert LSMinimumSystemVersion -string 27.0 "$plist"
/usr/bin/plutil -insert LSUIElement -bool true "$plist"
/usr/bin/plutil -insert NSHighResolutionCapable -bool true "$plist"
/usr/bin/plutil -insert NSPrincipalClass -string NSApplication "$plist"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"
printf 'Development bundle: %s\n' "$app"
if [[ "$mode" == "--run" ]]; then
    echo 'Running in this terminal; press Control-C to stop.'
    exec "$contents/MacOS/LovelyGlow"
fi
