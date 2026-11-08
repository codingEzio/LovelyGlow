import CoreGraphics
import Testing

@testable import LovelyGlowCore

struct TransitionRegressionTests {
    @Test func differentRefreshRateDisplaysDoNotSuppressEachOthersTicks() {
        var gate = FrameGate()
        let slow = gate.consume(100 + 1.0 / 120, displayID: 1)
        let fast = gate.consume(100 + 1.0 / 144, displayID: 2)
        let duplicate = gate.consume(100 + 1.0 / 120, displayID: 1)
        #expect(slow)
        #expect(fast)
        #expect(!duplicate)
    }

    @Test func windowAssignedToMultipleSpacesStillGlowsOnItsNormalDesktop() {
        var visibility = SpaceVisibility()
        let hidden = visibility.shouldHide(SpaceObservation(spaceID: 1, spaceType: 0, windowSpaceTypes: [0, 1]))
        #expect(!hidden)
    }

    @Test func activeWindowFollowIgnoresOtherWindowsAcrossLiveFrames() throws {
        let app = RunningAppSnapshot(pid: 42, bundleID: "fixture", name: "Fixture", isHidden: false)
        let display = DisplaySnapshot(bounds: CGRect(x: 0, y: 0, width: 1800, height: 1200))
        var windows = [snapshot(1, x: 100), snapshot(2, x: 700)]
        let decision = FocusResolver.resolve(
            enabled: true, frontApp: app, axWindow: nil, cgWindows: windows,
            displays: [display]
        )
        guard case .visible(let presentation) = decision else {
            Issue.record("Expected active target")
            return
        }
        let focused = try #require(presentation.focused?.window)
        #expect(WindowFollow.bounds(for: focused, in: windows) == focused.bounds)
        windows[1].bounds.origin.x += 40
        #expect(WindowFollow.bounds(for: focused, in: windows) == windows[0].bounds)
        windows[1].isOnscreen = false
        #expect(WindowFollow.bounds(for: focused, in: windows) == windows[0].bounds)
        windows[0].isOnscreen = false
        #expect(WindowFollow.bounds(for: focused, in: windows) == nil)
    }

    @Test func everyActualDisplayTickIsConsumedOnce() {
        for hz in [60.0, 80, 120, 144] {
            var gate = FrameGate()
            for frame in 0..<100 {
                let time = 100 + Double(frame) / hz
                let observed1 = gate.consume(time)
                #expect(observed1)
                let observed2 = !gate.consume(time)
                #expect(observed2)
            }
        }
    }

    @Test func fullscreenWindowCannotFlashWhileItsBoundsAreSliding() {
        var visibility = SpaceVisibility()
        let ordinary = SpaceObservation(spaceID: 1, spaceType: 0)
        let observed3 = !visibility.shouldHide(ordinary)
        #expect(observed3)
        // WindowServer still reports the desktop as active; Chrome already
        // belongs to its fullscreen Space, regardless of its animated bounds.
        let observed4 = visibility.shouldHide(
            SpaceObservation(spaceID: 1, spaceType: 0, windowSpaceTypes: [1], windowOnCurrentSpace: false))
        #expect(observed4)
        let observed5 = visibility.shouldHide(SpaceObservation(spaceID: 2, spaceType: 1, windowSpaceTypes: [1]))
        #expect(observed5)
        // Returning must not show an old rim on the first changed-Space sample.
        let observed6 = visibility.shouldHide(ordinary)
        #expect(observed6)
        #expect(visibility.needsConfirmation)
        let observed7 = !visibility.shouldHide(ordinary)
        #expect(observed7)
        #expect(!visibility.needsConfirmation)
    }

    @Test func cancelledSwipeWaitsForCoherentMembershipNotATimer() {
        var visibility = SpaceVisibility()
        let ordinary = SpaceObservation(spaceID: 1, spaceType: 0)
        let observed8 = !visibility.shouldHide(ordinary)
        #expect(observed8)
        let observed9 = visibility.shouldHide(SpaceObservation(spaceID: 1, spaceType: 0, windowOnCurrentSpace: false))
        #expect(observed9)
        let observed10 = visibility.shouldHide(ordinary)
        #expect(observed10)
        let observed11 = !visibility.shouldHide(ordinary)
        #expect(observed11)
    }

    @Test func reversedTravelStartsTowardTheNewTarget() {
        let old = GlowTravelState(x: 200, y: 100, w: 500, h: 300, vx: 5000, vw: 3000)
        let target = CGRect(x: 0, y: 100, width: 300, height: 300)
        let redirected = GlowTravel.retarget(old, to: target)
        #expect(redirected.rect == old.rect)
        let next = GlowTravel.step(state: redirected, target: target, dt: 1.0 / 120)
        #expect(next.x < old.x)
        #expect(next.w < old.w)
    }

    @Test func elapsedTimeIsNotRoundedToAFixedFrameRate() {
        let start = GlowTravelState.at(CGRect(x: 0, y: 0, width: 200, height: 100))
        let target = CGRect(x: 800, y: 200, width: 600, height: 500)
        #expect(GlowTravel.step(state: start, target: target, dt: 0) == start)
        let delayed = GlowTravel.step(state: start, target: target, dt: 0.1)
        var regular = start
        for _ in 0..<12 { regular = GlowTravel.step(state: regular, target: target, dt: 1.0 / 120) }
        #expect(abs(delayed.x - regular.x) < 0.001)
    }

    private func snapshot(_ id: UInt32, x: CGFloat) -> CGWindowSnapshot {
        CGWindowSnapshot(
            windowID: id, pid: 42, layer: 0, alpha: 1,
            bounds: CGRect(x: x, y: 100, width: 400, height: 600), isOnscreen: true)
    }
}
