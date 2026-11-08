import CoreGraphics
import Testing

@testable import LovelyGlowCore

struct RefinementTests {
    private let app = RunningAppSnapshot(pid: 42, bundleID: "com.example.browser", name: "Browser", isHidden: false)
    private let display = DisplaySnapshot(bounds: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    private let hoverCard = CGWindowSnapshot(
        windowID: 2, pid: 42, layer: 0, alpha: 1,
        bounds: CGRect(x: 330, y: 125, width: 310, height: 220), isOnscreen: true)
    private let browser = CGWindowSnapshot(
        windowID: 1, pid: 42, layer: 0, alpha: 1,
        bounds: CGRect(x: 100, y: 100, width: 1200, height: 760), isOnscreen: true)

    @Test func hoverCardDoesNotStealTheDefaultGlow() {
        let windows = [hoverCard, browser]
        let visual = FocusResolver.visualFront(
            cgWindows: windows, runningApps: [app], overlayWindowIDs: [], ownBundleID: "com.example.glow")
        #expect(visual?.window.windowID == 1)
        let decision = FocusResolver.resolve(
            enabled: true, frontApp: app, axWindow: nil, cgWindows: windows, displays: [display])
        guard case .visible(let presentation) = decision else {
            Issue.record("Expected the main browser window")
            return
        }
        #expect(presentation.focused?.window.cgWindowID == 1)
    }

    @Test func auxiliaryWindowCanBeIncludedExplicitly() {
        let windows = [hoverCard, browser]
        let visual = FocusResolver.visualFront(
            cgWindows: windows, runningApps: [app], overlayWindowIDs: [], ownBundleID: "com.example.glow",
            includeAuxiliaryWindows: true)
        #expect(visual?.window.windowID == 2)
        let decision = FocusResolver.resolve(
            enabled: true, frontApp: app, axWindow: nil, cgWindows: windows, displays: [display],
            includeAuxiliaryWindows: true)
        guard case .visible(let presentation) = decision else {
            Issue.record("Expected the hover card when enabled")
            return
        }
        #expect(presentation.focused?.window.cgWindowID == 2)
    }

    @Test func auxiliarySettingIsOffByDefaultAndPersists() {
        #expect(!SettingsDocument.default.includeAuxiliaryWindows)
        let parsed = SettingsDocument.parse("include_auxiliary_windows = true")
        #expect(parsed.includeAuxiliaryWindows)
        #expect(SettingsDocument.parse(parsed.serialized()).includeAuxiliaryWindows)
    }

    @Test func smallerSizeCanBeRestoredFromSettings() {
        #expect(GlowPanelMetrics.minimumSpread <= 2)
        #expect(SettingsDocument.parse("glow_spread = 2").style.spread == 2)
    }

    @Test func titledWindowInsideAnotherWindowIsStillEligible() {
        var document = hoverCard
        document.name = "Small Document"
        #expect(!FocusResolver.isAuxiliary(document, among: [document, browser]))
    }

    @Test func defaultCornerIsRounderThanThePriorContour() {
        #expect(WindowChrome.visualRadius(16) >= 24)
    }

    @Test func normalSpeedHasUsefulSliderSpaceOnBothSides() {
        let position = GlowMotion.sliderPosition(for: 1)
        #expect(position > 0.3 && position < 0.7)
        #expect(abs(GlowMotion.speed(atSliderPosition: position) - 1) < 0.000001)
        #expect(GlowMotion.speed(atSliderPosition: 0) == GlowMotion.minimumSpeed)
        #expect(GlowMotion.speed(atSliderPosition: 1) == GlowMotion.maximumSpeed)
    }
}
