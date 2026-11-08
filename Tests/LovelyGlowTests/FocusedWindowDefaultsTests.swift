import CoreGraphics
import Testing

@testable import LovelyGlowCore

struct FocusedWindowDefaultsTests {
    @Test func oldGroupingSettingsAreDiscardedOnSave() {
        for value in ["focused", "each", "union"] {
            let document = SettingsDocument.parse("window_grouping = \"\(value)\"")
            #expect(!document.serialized().contains("window_grouping"))
        }
    }

    @Test func defaultShowsOnlyOneWindowAcrossDisplays() throws {
        let targets = try resolvedTargets()
        #expect(targets.count == 1)
        #expect(targets.first?.window.cgWindowID == 1)
        #expect(targets.first?.window.trackingWindowIDs == [1])
    }

    @Test func clickingAnotherWindowMovesTheOnlyGlowToThatWindow() throws {
        let targets = try resolvedTargets(preferredID: 2)
        #expect(targets.count == 1)
        #expect(targets.first?.window.cgWindowID == 2)
        #expect(targets.first?.window.trackingWindowIDs == [2])
    }

    private func resolvedTargets(preferredID: UInt32? = nil) throws -> [GlowTarget] {
        let windows = [
            CGWindowSnapshot(
                windowID: 1, pid: 42, layer: 0, alpha: 1,
                bounds: CGRect(x: 100, y: 100, width: 600, height: 600), isOnscreen: true),
            CGWindowSnapshot(
                windowID: 2, pid: 42, layer: 0, alpha: 1,
                bounds: CGRect(x: 1700, y: 100, width: 600, height: 600), isOnscreen: true),
        ]
        let decision = FocusResolver.resolve(
            enabled: true, frontApp: RunningAppSnapshot(pid: 42, bundleID: "fixture", name: "Fixture", isHidden: false),
            axWindow: nil, cgWindows: windows,
            displays: [
                DisplaySnapshot(bounds: CGRect(x: 0, y: 0, width: 1600, height: 1000)),
                DisplaySnapshot(bounds: CGRect(x: 1600, y: 0, width: 1600, height: 1000)),
            ],
            preferredWindowID: preferredID)
        guard case .visible(let presentation) = decision else {
            Issue.record("Expected one focused window: \(decision)")
            return []
        }
        return presentation.targets
    }
}
