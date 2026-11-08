import CoreGraphics
import Testing

@testable import LovelyGlowCore

struct ExternalDisplayTests {
    private let external = DisplaySnapshot(bounds: CGRect(x: 0, y: 0, width: 2000, height: 1100))
    private let builtIn = DisplaySnapshot(bounds: CGRect(x: 300, y: 1100, width: 1500, height: 1000))

    @Test func anotherDisplaysFullscreenDoesNotHideAnOrdinaryExternalWindow() {
        let observation = SpaceSelection.observation(
            for: CGRect(x: 100, y: 100, width: 800, height: 600),
            displays: [
                DisplaySpaceSnapshot(bounds: external.bounds, spaceID: 8, spaceType: 0),
                DisplaySpaceSnapshot(bounds: builtIn.bounds, spaceID: 302, spaceType: 1),
            ], fallback: SpaceObservation(spaceID: 302, spaceType: 1))
        #expect(observation.spaceID == 8)
        #expect(observation.spaceType == 0)
    }

    @Test func onlyTheActiveWindowGlowsAcrossDisplays() throws {
        let a = window(1, CGRect(x: 100, y: 100, width: 500, height: 600))
        let b = window(2, CGRect(x: 800, y: 200, width: 500, height: 500))
        let c = window(3, CGRect(x: 500, y: 1200, width: 700, height: 600))
        let targets = try targets([a, b, c])
        #expect(targets.count == 1)
        #expect(targets.first?.window.bounds == a.bounds)
        #expect(targets.first?.window.trackingWindowIDs == [1])
    }

    @Test func ordinaryTiledWindowsKeepTheActiveRim() throws {
        let a = window(1, CGRect(x: 0, y: 0, width: 1000, height: 1100))
        let b = window(2, CGRect(x: 1000, y: 0, width: 1000, height: 1100))
        let targets = try targets([a, b])
        #expect(targets.count == 1)
        #expect(targets.map(\.window.bounds) == [a.bounds])
        #expect(targets.map(\.role) == [.focused])
    }

    @Test func fullscreenOnTheTargetsOwnDisplayStillHides() {
        let observation = SpaceSelection.observation(
            for: CGRect(x: 500, y: 1200, width: 700, height: 600),
            displays: [
                DisplaySpaceSnapshot(bounds: external.bounds, spaceID: 8, spaceType: 0),
                DisplaySpaceSnapshot(bounds: builtIn.bounds, spaceID: 302, spaceType: 1),
            ], fallback: SpaceObservation(spaceID: 8, spaceType: 0))
        var visibility = SpaceVisibility()
        let hidden = visibility.shouldHide(observation)
        #expect(hidden)
    }

    @Test func overviewStillHidesAcrossDisplays() {
        let observation = SpaceSelection.observation(
            for: CGRect(x: 100, y: 100, width: 800, height: 600),
            displays: [
                DisplaySpaceSnapshot(bounds: external.bounds, spaceID: 8, spaceType: 0),
                DisplaySpaceSnapshot(bounds: builtIn.bounds, spaceID: 302, spaceType: 2),
            ], fallback: SpaceObservation(spaceID: 8, spaceType: 0))
        #expect(observation.spaceType == 2)
    }

    @Test func displaySelectionUsesOverlapAndKeepsOffDesktopFallback() {
        let left = CGRect(x: -1800, y: -100, width: 1800, height: 1100)
        let right = CGRect(x: 0, y: 0, width: 2000, height: 1100)
        #expect(
            WindowGeometry.displayIndex(for: CGRect(x: -500, y: 100, width: 600, height: 400), in: [left, right]) == 0)
        let fallback = SpaceObservation(spaceID: 17, spaceType: 0)
        let observation = SpaceSelection.observation(
            for: CGRect(x: 4000, y: 4000, width: 500, height: 400),
            displays: [DisplaySpaceSnapshot(bounds: left, spaceID: 8, spaceType: 0)], fallback: fallback)
        #expect(observation == fallback)
    }

    private func targets(_ windows: [CGWindowSnapshot]) throws -> [GlowTarget] {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: RunningAppSnapshot(pid: 42, bundleID: "fixture", name: "Fixture", isHidden: false),
            axWindow: nil, cgWindows: windows, displays: [external, builtIn])
        guard case .visible(let result) = decision else {
            Issue.record("Ordinary windows must keep their glow: \(decision)")
            return []
        }
        return result.targets
    }

    private func window(_ id: UInt32, _ bounds: CGRect) -> CGWindowSnapshot {
        CGWindowSnapshot(windowID: id, pid: 42, layer: 0, alpha: 1, bounds: bounds, isOnscreen: true)
    }
}
