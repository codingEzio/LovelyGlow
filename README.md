<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

The optional Pixel typeface uses DeparturePixelZh Compact 0.1.1. It is not included here. Run `python3 script/get_compact_font.py` to download and verify the pinned release before packaging. See [dependencies](DEPENDENCIES.md) for notices and scope. For a local font, set `LOVELYGLOW_PRIVATE_FONT` to its file path when building. Keep it outside the repository or under ignored `Local/`; it is validated before bundling; optionally set `LOVELYGLOW_PRIVATE_FONT_NOTICES` to a directory of its notices. If omitted, the bundle says no notices were supplied.

A native macOS menu-bar accessory that draws one rim around the focused window.
It uses SwiftUI, AppKit, Metal and window-system observations. It does not dim
content, tile windows or attach to another app's window.

Product and permission identity remain `Lovely Glow`, `LovelyGlow.app`,
`LovelyGlow` and `com.alex.LovelyGlow`.

### Run a development app

Run `./script/dev.sh --run` from the checkout; it builds an ad-hoc signed app without a signing certificate and runs it in the terminal. Press Control-C or use the app's Quit command to stop it. `./script/dev.sh --build` only builds and prints the bundle path; `just dev` and `just dev-build` are equivalents. Each build creates a new `Local/lovelyglow-dev.*` directory and reuses the `Local/swift-dev-build` SwiftPM cache. After stopping the app, remove unneeded bundle directories manually; remove the cache when no build is running to reclaim space. Failed build directories also remain.

The development app uses `com.github.codingEzio.LovelyGlow.Development` and `~/Library/Application Support/com.github.codingEzio.LovelyGlow.Development/config.toml`, separate from the installed app. Settings persist between development runs; remove that directory manually only if you want to discard them. Use the permission control to request Accessibility; startup does not request it. If you enable launch at login, disable it in the development app before deleting its bundle. macOS may retain permission records after cleanup. The optional font is included only if downloaded or supplied and verified; the system font works without it. This path does not install or replace the signed product.

## Source build and tests

Requires macOS 27+, an Apple Silicon Mac with a compatible Xcode/Swift 6.2+
macOS SDK selected by `xcode-select` or `DEVELOPER_DIR`. The current preparation
was checked on arm64 macOS with Swift 6.4; Intel and other hosts are unverified.
There are no downloaded Swift packages or sibling-repository build dependencies.
Install Xcode and accept its license through Apple's normal setup first.

From the checkout, including a path containing spaces:

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
```

`just` is needed only for the existing command shortcuts. The equivalent test
command is `swift test --jobs 2 --scratch-path Local/swift-test`. Tests exercise
core models and read source files; they do not start the app, request
Accessibility, install a bundle or change login items. `SWIFT_JOBS` (default 2)
and `SWIFT_SCRATCH_PATH` (default `Local/swift-test`) configure `just test`.
Invalid Swift options fail visibly. Build/test output stays separate from
settings at `~/Library/Application Support/com.alex.LovelyGlow/config.toml`.

`Package.swift` reads `config/product.conf` when present. Otherwise it reads
`config/product.public.conf`, which contains the same product identity and no
signing identity. Missing or malformed configuration fails the build. The
private signing configuration is omitted from this repository.

A SwiftPM executable is compile evidence, not a signed app bundle or a tested
running overlay. Do not launch it to replace the installed app.

## Local packaging and operation

The existing `just stage`, `just package`, `just run`, `just verify` and
`just install` commands are for an owner-configured checkout with
`config/product.conf` and its matching local signing certificate. They are not
part of source preparation. `stage`/`package` replace the candidate under
`dist/`, render the icon and sign it; they do not stop the installed app.
`run`/`verify` also launch a candidate. `install` replaces and relaunches
`~/Applications/LovelyGlow.app` only if its designated requirement matches. Do
not substitute an ad-hoc identity or change the bundle identity to bypass it.

Packaging also uses the native `iconutil`/`sips` tools, optional Homebrew
`rsvg-convert`, and a Python 3 standard-library icon fallback. A source build does not establish signed packaging or installation. The
installed app uses the same Application Support settings path as source builds.
The installer reads the previous signed app’s legacy path, verifies an exact
copy before replacement, and refuses a conflicting destination without overwriting
either file. Its Python 3 migration check is
`python3 -m unittest discover -s script -p test_migrate_settings.py`.
The legacy file remains recoverable; it is no longer a settings writer.

Use the permission control to request Accessibility; startup does not request it. Without access, ordinary app switches
use window-system bounds and live drag-follow is weaker. Settings use a native
menu-bar popover; Quit stops the app. Login start uses `SMAppService` only when
the user enables it. No web service, LaunchAgent or Process Compose is needed.

## Behavior and limits

- One focused window is highlighted; small untitled auxiliary windows are
  excluded unless enabled in More.
- The rim follows the display cadence, supports selectable motion and palette,
  and stays click-through. System typeface is the default; bundled Pixel Compact
  is optional and persisted.
- Fullscreen, Mission Control and work-area-filling windows suppress the rim.
  Space/overview detection uses optional window-server symbols, so future macOS
  compatibility needs separate verification.
- Core tests do not prove actual Accessibility state, display smoothness, visual
  alignment or physical gestures. Stage Manager and custom-shaped windows remain
  limited.

## Licenses and local review

The README mark is a separate documentation SVG by codingEzio under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Its grant does not change product icon, font or third-party rights.

Original software uses [MIT](LICENSE). The optional font retains its complete
[OFL and component notices](Resources/Licenses/NOTICE.md); it is not relicensed.
[LICENSE-SCOPE.md](LICENSE-SCOPE.md) separates software, font and icon rights.
This repository excludes the original private mark and carries a generic
CC BY 4.0 SVG placeholder; private packaging still uses its original mark. See
[artwork](ARTWORK.md), [繁體中文](ARTWORK.zh-TW.md),
[简体中文](ARTWORK.zh-CN.md).

See [PUBLICATION.md](PUBLICATION.md) for the source history and verification limits.
