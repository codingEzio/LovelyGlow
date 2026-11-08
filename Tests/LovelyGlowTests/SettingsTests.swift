import Testing

@testable import LovelyGlowCore

struct SettingsTests {
    @Test func defaultsFirstPaintAsSystem() {
        #expect(SettingsDocument.default.fontStyle == .system)
        #expect(SettingsDocument.default.enabled)
        #expect(SettingsDocument.default.language == .auto)
        #expect(SettingsDocument.default.glowAboveDock)
        #expect(!SettingsDocument.default.includeAuxiliaryWindows)
        #expect(SettingsDocument.default.animation == .orbitBreathe)
        #expect(SettingsDocument.default.scheme == .violetBloom)
        #expect(SettingsDocument.default.animationSpeed == 1)
        #expect(SettingsDocument.default.arrival == .instant)
    }

    @Test func parseIgnoresUnknownKeysAndClamps() {
        let document = SettingsDocument.parse(
            """
            enabled = false
            font_style = "pixel"
            ui_language = "zh-Hant"
            glow_spread = 99
            glow_line_width = 0.2
            glow_opacity = 0.05
            glow_speed = 40
            window_grouping = "union"
            glow_animation = "comet"
            color_scheme = "sunset"
            glow_arrival = "seamless"
            light_color = "#112233"
            mystery = "nope"
            """
        )
        #expect(document.enabled == false)
        #expect(document.fontStyle == .pixel)
        #expect(document.language == .zhHant)
        #expect(document.style.spread == GlowPanelMetrics.maximumSpread)
        #expect(document.style.lineWidth == 1)
        #expect(document.style.opacity == 0.2)
        #expect(document.style.lightColor.hex == "#112233")
        #expect(document.glowAboveDock)
        #expect(!document.serialized().contains("window_grouping"))
        #expect(document.animation == .comet)
        #expect(document.scheme == .sunset)
        #expect(document.animationSpeed == GlowMotion.maximumSpeed)
        #expect(document.arrival == .seamless)
    }

    @Test func spreadBelowTheUsableRangeIsClamped() {
        let document = SettingsDocument.parse("glow_spread = 0")
        #expect(document.style.spread == GlowPanelMetrics.minimumSpread)
    }

    @Test func compactPopoverMatchesCalmBarAndHWStatus() {
        #expect(GlowPanelMetrics.width == 300)
        #expect(GlowPanelMetrics.inset == 12)
        #expect(GlowPanelMetrics.contentWidth == 276)
        #expect(GlowPanelMetrics.sectionSpacing == 7)
        #expect(GlowPanelMetrics.cornerRadius == 18)
        #expect(
            GlowPopoverDismissal.shouldDismiss(clickedPanel: true, clickedStatusItem: false, clickedMenu: false)
                == false)
        #expect(
            GlowPopoverDismissal.shouldDismiss(clickedPanel: false, clickedStatusItem: true, clickedMenu: false)
                == false)
        #expect(
            GlowPopoverDismissal.shouldDismiss(clickedPanel: false, clickedStatusItem: false, clickedMenu: true)
                == false)
        #expect(GlowPopoverDismissal.shouldDismiss(clickedPanel: false, clickedStatusItem: false, clickedMenu: false))
    }

    @Test func existingColorOnlyConfigStaysCustom() {
        let document = SettingsDocument.parse(
            """
            light_color = "#7A4DFF"
            dark_color = "#F4D6FF"
            """
        )
        #expect(document.scheme == .custom)
        #expect(document.style.lightColor.hex == "#7A4DFF")
    }

    @Test func parseCanPutTheGlowBelowTheDock() {
        let document = SettingsDocument.parse("glow_above_dock = false")
        #expect(document.glowAboveDock == false)
    }

    @Test func parseAndSerializeRoundTrip() {
        var document = SettingsDocument.default
        document.enabled = false
        document.launchAtLogin = true
        document.fontStyle = .pixel
        document.language = .ja
        document.style.spread = 16
        document.style.lightColor = RGBAColor.parse("#AABBCC")!
        let again = SettingsDocument.parse(document.serialized())
        #expect(again == document)
    }

    @Test func colorHexSupportsAlpha() {
        #expect(RGBAColor.parse("#ff00aa80")?.hex == "#FF00AA80")
        #expect(RGBAColor.parse("not-a-color") == nil)
    }

    @Test func paletteKeepsHighlightAndWarmthDistinct() {
        let palette = GlowStyle.default.palette(isDark: true)
        #expect(palette.highlight != palette.base)
        #expect(palette.warmth != palette.base)
        #expect(palette.highlight != palette.warmth)
    }
}
