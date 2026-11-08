# License scope

[MIT](LICENSE) covers project-authored software in `Sources/`, `Tests/`,
`script/`, `Package.swift`, `justfile`, configuration templates and project
documentation. It excludes bundled artwork, font data and third-party notices,
including image payloads embedded in a code file. Preserve existing attribution.

The separately obtained `Resources/Fonts/DeparturePixelZhCompact-Regular.ttf`
uses the 0.1.1 records in `Resources/Licenses/`; it is not in this source
repository. The 0.1.1 name-table license description differs from 0.1.0. Preserve its NOTICE, OFL, provenance
and all 25 component notices when embedding the font. Font Logos and Material
Design glyph rights and trademarks remain unresolved; no distribution right is
inferred from the download or source comparison.

`Resources/LovelyGlow.svg` is retained privately, unchanged, but excluded from
this repository. Its first Git import does not establish original authorship
or redistribution rights. No license is asserted for that mark.

`Resources/PublicIcon.svg` is a new deterministic grayscale window placeholder
made for this source package, with its exact SHA-256 in
Resources/PublicIcon.json. The contributors license owned rights in this
placeholder under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Credit Lovely Glow project contributors, retain the receipt and license link,
and indicate changes. Third-party rights and trademarks are not granted. This is
not a replacement for the installed product identity. The private packager still
selects the original mark whenever it is present; this repository uses the
generic placeholder. See ARTWORK.md, ARTWORK.zh-TW.md and ARTWORK.zh-CN.md.

`docs/icon.svg` is a separate original documentation mark, licensed by
codingEzio under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Only that SVG is covered by this new grant. Credit codingEzio, retain the license
link and indicate changes; its exact hash and source are recorded in
[ARTWORK-LICENSE.md](ARTWORK-LICENSE.md). It is used in README/local portal
presentation and does not replace the app icon or alter either artwork scope
above. MIT's documentation grant excludes this SVG. Fonts, third-party assets,
trademarks and the unresolved original mark retain their existing boundaries.

License scope does not imply rights to third-party trademarks.
