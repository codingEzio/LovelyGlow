# Dependencies and configuration

| Component | Use and source | Acquisition / license / scope |
| --- | --- | --- |
| Swift 6.2+ and macOS 27+ SDK | SwiftPM manifest, native app and tests | Apple's Xcode toolchain; separately installed; no Swift package downloads |
| AppKit, SwiftUI, Metal, CoreGraphics, CoreText, QuartzCore, ApplicationServices, ServiceManagement | Native UI, rendering, fonts, observations and optional login start | OS/SDK frameworks; Apple terms; macOS runtime only |
| just | Existing command shortcuts | Optional separately installed CLI; direct SwiftPM commands work without it |
| Python 3 | Source review/export and existing icon-packaging fallback | Standard library only; separately installed/toolchain-provided; explicit Compact download needs network |
| Bash and native macOS tools | Existing owner packaging/install scripts | OS tools; signing needs the owner's existing local certificate; no certificate is bundled |
| librsvg `rsvg-convert` | Optional icon renderer used by existing packaging | Separately installed; not needed for source compile/tests |
| DeparturePixelZh Compact 0.1.1 | Optional pixel typeface for packaged builds | Not included in source; explicit pinned desktop release download; bundled only during packaging with OFL 1.1 and component notices; no runtime download |

This repository uses Compact 0.1.1 and excludes the font binary.
Run `python3 script/get_compact_font.py` to obtain the pinned official desktop
release; the ZIP and TTF hashes are verified before atomic publication. A source
compile does not require it, but default packaging refuses a missing or mismatched input.
An explicit `LOVELYGLOW_PRIVATE_FONT` file path overrides the pinned input for
local packaging and development builds. CoreText validates the supplied file
and the bundled copy; a missing or invalid explicit input fails. The override
is not stored in Git. The public font notices are not bundled with an override.
Optionally set `LOVELYGLOW_PRIVATE_FONT_NOTICES` to a readable, nonempty directory
of notices; an invalid explicit directory fails. Without it the bundle states
that no notices were supplied. File checks do not establish rights or notice
completeness. Without an override the pinned check remains mandatory
for packaging; development builds may omit the font entirely.
The 0.1.1 TTF SHA-256 is
`3e75e623b1ba2c8d7eb52f2ac3ee71c3fbb5c4e0f1426bd34b3c1e071738288b`.
The previous 0.1.0 TTF SHA-256 was
`74adf4919c690e61aa7bdd4c369a6f5c84029413a7da5e85d687ea7fa6b502e7`.
The two versions have identical glyph and layout tables, but `head` and `name`
differ, including name ID 13's license description. The included 0.1.1
provenance and notices replace the earlier version's records. Hash identity and
local comparisons do not establish permission to redistribute every icon or
trademark; third-party trademark terms still apply. Preserve all included notices
when embedding or redistributing a font. No installed app has been changed.

`config/product.conf` is the existing private packaging authority and takes
precedence for SwiftPM. The public source template is used only when that file
is absent. Its empty signing identity deliberately cannot satisfy the existing
packaging loader. Installed app identity, install path and certificate are not
changed. Runtime settings live at
`~/Library/Application Support/com.alex.LovelyGlow/config.toml`, outside the
source checkout. Public exports omit settings and operational evidence.

Optional window-server symbols may be unavailable on another OS version.
The existing implementation falls back to its window/fullscreen rules with
weaker Space evidence. Source compilation does not establish runtime support.
