import CoreGraphics
import Testing

@testable import LovelyGlowCore

struct FocusResolverTests {
    private let safari = RunningAppSnapshot(
        pid: 42,
        bundleID: "com.apple.Safari",
        name: "Safari",
        isHidden: false
    )
    private let display = DisplaySnapshot(
        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visible: CGRect(x: 0, y: 28, width: 1512, height: 954)
    )
    private let windowBounds = CGRect(x: 120, y: 80, width: 900, height: 640)

    @Test func disabledHidesGlow() {
        let decision = FocusResolver.resolve(
            enabled: false,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7)],
            displays: [display]
        )
        #expect(decision == .hidden(.disabled))
    }

    @Test func missingFrontAppHidesGlow() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: nil,
            axWindow: nil,
            cgWindows: [cgWindow(id: 7)],
            displays: [display]
        )
        #expect(decision == .hidden(.noFrontApp))
    }

    @Test func dockAndSpotlightHoldThePreviousGlow() {
        for bundleID in ["com.apple.dock", "com.apple.Spotlight"] {
            let app = RunningAppSnapshot(pid: 9, bundleID: bundleID, name: "System", isHidden: false)
            let decision = FocusResolver.resolve(
                enabled: true,
                frontApp: app,
                axWindow: AXWindowSnapshot(pid: 9, bounds: windowBounds, isMinimized: false, isFullscreen: false),
                cgWindows: [cgWindow(id: 3, pid: 9)],
                displays: [display]
            )
            #expect(decision == .hold)
        }
    }

    @Test func ownPopoverDoesNotStealTheGlow() {
        let app = RunningAppSnapshot(
            pid: 15,
            bundleID: "com.alex.LovelyGlow",
            name: "Lovely Glow",
            isHidden: false
        )
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: app,
            axWindow: AXWindowSnapshot(pid: 15, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 9, pid: 15)],
            displays: [display]
        )
        #expect(decision == .hold)
    }

    @Test func hiddenAppHidesGlowWhenNothingSitsUnderneath() {
        var app = safari
        app.isHidden = true
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: app,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7)],
            displays: [display]
        )
        #expect(decision == .hidden(.hiddenApp))
    }

    @Test func hiddenAppGlowsTheWindowUnderneath() {
        var hiddenSafari = safari
        hiddenSafari.isHidden = true
        let chrome = RunningAppSnapshot(
            pid: 77,
            bundleID: "com.google.Chrome",
            name: "Chrome",
            isHidden: false
        )
        let chromeBounds = CGRect(x: 200, y: 90, width: 720, height: 520)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: hiddenSafari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [
                cgWindow(id: 7, pid: 42),
                cgWindow(id: 21, pid: 77, bounds: chromeBounds),
            ],
            displays: [display],
            runningApps: [hiddenSafari, chrome]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(
                        pid: 77,
                        bundleID: "com.google.Chrome",
                        cgWindowID: 21,
                        bounds: chromeBounds
                    )
                )
        )
    }

    @Test func hiddenAppDoesNotFollowDockOrOurOwnPopover() {
        var hiddenSafari = safari
        hiddenSafari.isHidden = true
        let dock = RunningAppSnapshot(pid: 9, bundleID: "com.apple.dock", name: "Dock", isHidden: false)
        let glow = RunningAppSnapshot(
            pid: 15,
            bundleID: "com.alex.LovelyGlow",
            name: "Lovely Glow",
            isHidden: false,
            isRegular: false
        )
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: hiddenSafari,
            axWindow: nil,
            cgWindows: [
                cgWindow(id: 3, pid: 9, bounds: display.bounds),
                cgWindow(id: 9, pid: 15),
            ],
            displays: [display],
            runningApps: [hiddenSafari, dock, glow]
        )
        #expect(decision == .hidden(.hiddenApp))
    }

    @Test func missionControlHidesGlow() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7)],
            displays: [display],
            missionControl: true
        )
        #expect(decision == .hidden(.missionControl))
    }

    @Test func missionControlHidesInsteadOfHoldingDock() {
        let dock = RunningAppSnapshot(pid: 9, bundleID: "com.apple.dock", name: "Dock", isHidden: false)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: dock,
            axWindow: nil,
            cgWindows: [cgWindow(id: 3, pid: 9, bounds: display.bounds)],
            displays: [display],
            missionControl: true
        )
        #expect(decision == .hidden(.missionControl))
    }

    @Test func minimizedFocusedWindowFallsThroughToASibling() {
        let other = CGRect(x: 600, y: 80, width: 400, height: 300)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: true, isFullscreen: false),
            cgWindows: [cgWindow(id: 8, bounds: other)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 8, bounds: other)
                )
        )
    }

    @Test func axWindowWinsWhenSizeIsUsable() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: windowBounds.insetBy(dx: 4, dy: 4))],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 7, bounds: windowBounds)
                )
        )
    }

    @Test func axFullscreenHidesGlow() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: display.bounds, isMinimized: false, isFullscreen: true),
            cgWindows: [cgWindow(id: 7, bounds: display.bounds)],
            displays: [display]
        )
        #expect(decision == .hidden(.fullscreen))
    }

    @Test func axFullscreenFlagOnAZoomedWindowStillGlows() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: false, isFullscreen: true),
            cgWindows: [cgWindow(id: 7, bounds: windowBounds)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 7, bounds: windowBounds)
                )
        )
    }

    @Test func displayFillingWindowHidesGlow() {
        let filling = display.bounds
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: filling, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: filling)],
            displays: [display]
        )
        #expect(decision == .hidden(.fullscreen))
    }

    @Test func nativeFullscreenLeavingAMenuBarStripHidesGlow() {
        let strip = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: strip, isMinimized: false, isFullscreen: true),
            cgWindows: [cgWindow(id: 7, bounds: strip)],
            displays: [display]
        )
        #expect(decision == .hidden(.fullscreen))
        #expect(FocusResolver.coversDisplayIgnoringMenuBar(strip, display: display))
    }

    @Test func aTallFullWidthWindowNotAtTheTopStillGlows() {
        let hanging = CGRect(x: 0, y: 80, width: 1512, height: 940)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: hanging, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: hanging)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 7, bounds: hanging)
                )
        )
        #expect(!FocusResolver.coversDisplayIgnoringMenuBar(hanging, display: display))
    }

    @Test func axFullscreenOnAMostlyFilledDisplayHidesGlow() {
        let almost = CGRect(x: 40, y: 40, width: 1400, height: 860)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: almost, isMinimized: false, isFullscreen: true),
            cgWindows: [cgWindow(id: 7, bounds: almost)],
            displays: [display]
        )
        #expect(decision == .hidden(.fullscreen))
    }

    @Test func maximizedWorkAreaHidesGlow() {
        let visible = display.visible
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: visible, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: visible)],
            displays: [display]
        )
        #expect(decision == .hidden(.fullscreen))
    }

    @Test func lowerDisplayVisibleFrameHidesGlow() {
        let secondary = DisplaySnapshot(
            bounds: CGRect(x: 316, y: 1152, width: 1496, height: 967),
            visible: CGRect(x: 316, y: 1180, width: 1496, height: 939)
        )
        let visible = secondary.visible
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: visible, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: visible)],
            displays: [display, secondary]
        )
        #expect(decision == .hidden(.fullscreen))
    }

    @Test func minimizedAXWindowHidesGlow() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: windowBounds, isMinimized: true, isFullscreen: false),
            cgWindows: [cgWindow(id: 7)],
            displays: [display]
        )
        #expect(decision == .hidden(.minimized))
    }

    @Test func laggedAXDuringADragUsesTheLiveCGWindow() {
        let lagged = windowBounds
        let live = windowBounds.offsetBy(dx: 48, dy: 22)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: lagged, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 7, bounds: live)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 7, bounds: live)
                )
        )
        #expect(FocusResolver.trackingBounds(ax: lagged, cg: live) == live)
        #expect(FocusResolver.trackingBounds(ax: lagged, cg: lagged.insetBy(dx: 4, dy: 4)) == lagged)
        let resized = CGRect(x: live.minX, y: live.minY, width: 820, height: 500)
        #expect(FocusResolver.trackingBounds(ax: live, cg: resized) == resized)
    }

    @Test func tabChromeUsesTheOuterCGWindow() {
        let chrome = CGRect(x: 66, y: 30, width: 991, height: 561)
        let tabContent = CGRect(x: 66, y: 70, width: 991, height: 521)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: tabContent, isMinimized: false, isFullscreen: false),
            cgWindows: [
                cgWindow(id: 8, bounds: tabContent),
                cgWindow(id: 7, bounds: chrome),
            ],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 7, bounds: chrome)
                )
        )
    }

    @Test func tinyAXWindowFallsThroughToCG() {
        let tiny = CGRect(x: 10, y: 10, width: 40, height: 20)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: tiny, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 11)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 11, bounds: windowBounds)
                )
        )
    }

    @Test func cgFallbackUsesFrontmostUsableWindow() {
        let electron = RunningAppSnapshot(
            pid: 88,
            bundleID: "com.microsoft.VSCode",
            name: "Code",
            isHidden: false
        )
        let tooltip = cgWindow(id: 1, pid: 88, bounds: CGRect(x: 20, y: 20, width: 36, height: 18))
        let helper = cgWindow(id: 2, pid: 88, layer: 8, bounds: windowBounds)
        let content = cgWindow(id: 3, pid: 88, bounds: windowBounds)
        let otherApp = cgWindow(id: 4, pid: 99, bounds: windowBounds)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: electron,
            axWindow: nil,
            cgWindows: [tooltip, helper, otherApp, content],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(
                        pid: 88,
                        bundleID: "com.microsoft.VSCode",
                        cgWindowID: 3,
                        bounds: windowBounds
                    )
                )
        )
    }

    @Test func overlayWindowIDsAreIgnored() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: nil,
            cgWindows: [cgWindow(id: 50), cgWindow(id: 51, bounds: windowBounds.offsetBy(dx: 30, dy: 20))],
            displays: [display],
            overlayWindowIDs: [50]
        )
        #expect(
            decision
                == .glowing(
                    FocusedWindow(
                        pid: 42,
                        bundleID: "com.apple.Safari",
                        cgWindowID: 51,
                        bounds: windowBounds.offsetBy(dx: 30, dy: 20)
                    )
                )
        )
    }

    @Test func missingWindowsHideGlow() {
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: nil,
            cgWindows: [cgWindow(id: 1, layer: 3)],
            displays: [display]
        )
        #expect(decision == .hidden(.noWindow))
    }

    @Test func twoSideBySideWindowsKeepOnlyTheFocusedGlow() {
        let left = CGRect(x: 40, y: 80, width: 500, height: 400)
        let right = CGRect(x: 600, y: 80, width: 500, height: 400)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: left, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 1, bounds: left), cgWindow(id: 2, bounds: right)],
            displays: [display]
        )
        #expect(
            decision
                == .glowing(FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 1, bounds: left))
        )
    }

    @Test func overlappingNamedWindowCanStillBeFocused() {
        let focused = CGRect(x: 200, y: 150, width: 400, height: 300)
        let bigger = CGRect(x: 80, y: 80, width: 900, height: 640)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: focused, isMinimized: false, isFullscreen: false),
            cgWindows: [
                CGWindowSnapshot(
                    windowID: 1, pid: 42, layer: 0, alpha: 1,
                    bounds: focused, isOnscreen: true, name: "Document"),
                cgWindow(id: 2, bounds: bigger),
            ],
            displays: [display]
        )
        guard case .visible(let presentation) = decision else {
            Issue.record("expected visible presentation")
            return
        }
        #expect(presentation.focused?.window.bounds == focused)
        #expect(presentation.focused?.window.cgWindowID == 1)
        #expect(presentation.targets.count == 1)
        #expect(presentation.focused?.window.bounds != bigger)
    }

    @Test func tabContentIsNotASecondGlowTarget() {
        let chrome = CGRect(x: 66, y: 30, width: 991, height: 561)
        let tabContent = CGRect(x: 66, y: 70, width: 991, height: 521)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: tabContent, isMinimized: false, isFullscreen: false),
            cgWindows: [
                cgWindow(id: 8, bounds: tabContent),
                cgWindow(id: 7, bounds: chrome),
            ],
            displays: [display]
        )
        guard case .visible(let presentation) = decision else {
            Issue.record("expected visible presentation")
            return
        }
        #expect(presentation.targets.count == 1)
        #expect(presentation.focused?.window.bounds == chrome)
        #expect(presentation.focused?.window.cgWindowID == 7)
    }

    @Test func visualFrontLooksThroughDockToTheRegularApp() {
        let dock = RunningAppSnapshot(pid: 9, bundleID: "com.apple.dock", name: "Dock", isHidden: false)
        let chrome = RunningAppSnapshot(
            pid: 77,
            bundleID: "com.google.Chrome",
            name: "Chrome",
            isHidden: false
        )
        let chromeBounds = CGRect(x: 200, y: 90, width: 720, height: 520)
        let visual = FocusResolver.visualFront(
            cgWindows: [
                cgWindow(id: 3, pid: 9, bounds: display.bounds),
                cgWindow(id: 21, pid: 77, bounds: chromeBounds),
            ],
            runningApps: [dock, chrome],
            overlayWindowIDs: [],
            ownBundleID: "com.alex.LovelyGlow"
        )
        #expect(visual?.app.pid == 77)
        #expect(visual?.window.windowID == 21)
    }

    @Test func visualFrontSkipsOurOverlayAndTinyHelpers() {
        let glow = RunningAppSnapshot(
            pid: 15,
            bundleID: "com.alex.LovelyGlow",
            name: "Lovely Glow",
            isHidden: false,
            isRegular: false
        )
        let visual = FocusResolver.visualFront(
            cgWindows: [
                cgWindow(id: 9, pid: 15),
                cgWindow(id: 1, bounds: CGRect(x: 0, y: 0, width: 20, height: 20)),
                cgWindow(id: 7),
            ],
            runningApps: [glow, safari],
            overlayWindowIDs: [9],
            ownBundleID: "com.alex.LovelyGlow"
        )
        #expect(visual?.window.windowID == 7)
        #expect(visual?.app.pid == 42)
    }

    @Test func visualAtPicksTheWindowUnderTheClickWhileZOrderLags() {
        let chrome = RunningAppSnapshot(
            pid: 77,
            bundleID: "com.google.Chrome",
            name: "Chrome",
            isHidden: false
        )
        let front = CGRect(x: 40, y: 80, width: 500, height: 400)
        let behind = CGRect(x: 600, y: 80, width: 500, height: 400)
        let click = CGPoint(x: 820, y: 200)
        let windows = [
            cgWindow(id: 1, bounds: front),
            cgWindow(id: 21, pid: 77, bounds: behind),
        ]
        let zOrder = FocusResolver.visualFront(
            cgWindows: windows,
            runningApps: [safari, chrome],
            overlayWindowIDs: [],
            ownBundleID: "com.alex.LovelyGlow"
        )
        let hit = FocusResolver.visualAt(
            point: click,
            cgWindows: windows,
            runningApps: [safari, chrome],
            overlayWindowIDs: [],
            ownBundleID: "com.alex.LovelyGlow"
        )
        #expect(zOrder?.window.windowID == 1)
        #expect(hit?.window.windowID == 21)
        #expect(hit?.app.pid == 77)
    }

    @Test func visualAtLooksThroughOurOverlay() {
        let click = CGPoint(x: 820, y: 200)
        let behind = CGRect(x: 600, y: 80, width: 500, height: 400)
        let hit = FocusResolver.visualAt(
            point: click,
            cgWindows: [
                cgWindow(id: 9, pid: 15, bounds: behind),
                cgWindow(id: 21, pid: 77, bounds: behind),
            ],
            runningApps: [
                RunningAppSnapshot(
                    pid: 15,
                    bundleID: "com.alex.LovelyGlow",
                    name: "Lovely Glow",
                    isHidden: false,
                    isRegular: false
                ),
                RunningAppSnapshot(
                    pid: 77,
                    bundleID: "com.google.Chrome",
                    name: "Chrome",
                    isHidden: false
                ),
            ],
            overlayWindowIDs: [9],
            ownBundleID: "com.alex.LovelyGlow"
        )
        #expect(hit?.window.windowID == 21)
        #expect(hit?.app.pid == 77)
    }

    @Test func preferredWindowIDGlowsTheClickedSiblingWhileZOrderLags() {
        let front = CGRect(x: 40, y: 80, width: 500, height: 400)
        let behind = CGRect(x: 600, y: 80, width: 500, height: 400)
        let decision = FocusResolver.resolve(
            enabled: true,
            frontApp: safari,
            axWindow: AXWindowSnapshot(pid: 42, bounds: front, isMinimized: false, isFullscreen: false),
            cgWindows: [cgWindow(id: 1, bounds: front), cgWindow(id: 2, bounds: behind)],
            displays: [display],
            preferredWindowID: 2
        )
        #expect(
            decision
                == .glowing(FocusedWindow(pid: 42, bundleID: "com.apple.Safari", cgWindowID: 2, bounds: behind))
        )
    }

    @Test func pointerHoldSticksWhileZOrderLagsThenReleases() {
        #expect(FocusResolver.shouldHoldPointer(preferredID: 21, laggingID: 1, zOrderID: 1))
        #expect(!FocusResolver.shouldHoldPointer(preferredID: 21, laggingID: 1, zOrderID: 21))
        #expect(!FocusResolver.shouldHoldPointer(preferredID: 21, laggingID: 1, zOrderID: 9))
        #expect(!FocusResolver.shouldHoldPointer(preferredID: 21, laggingID: nil, zOrderID: 9))
        #expect(FocusResolver.shouldHoldPointer(preferredID: 21, laggingID: 1, zOrderID: nil))
    }

    @Test func visualPollIgnoresBoundsJitterOnTheSameWindow() {
        #expect(
            !FocusResolver.visualIdentityChanged(lastID: 7, lastPID: 42, visualID: 7, visualPID: 42)
        )
        #expect(
            FocusResolver.visualIdentityChanged(lastID: 7, lastPID: 42, visualID: 21, visualPID: 42)
        )
        #expect(
            FocusResolver.visualIdentityChanged(lastID: 7, lastPID: 42, visualID: 7, visualPID: 77)
        )
    }

    @Test func liveResizePrefersAXSizeAndLiveCGOrigin() {
        let ax = windowBounds
        let moved = windowBounds.offsetBy(dx: 48, dy: 22)
        let resized = CGRect(x: windowBounds.minX, y: windowBounds.minY, width: 820, height: 500)
        #expect(FocusResolver.liveResizeBounds(ax: resized, cg: windowBounds) == resized)
        #expect(FocusResolver.liveResizeBounds(ax: ax, cg: moved) == moved)
    }

    private func cgWindow(
        id: UInt32,
        pid: Int32 = 42,
        layer: Int = 0,
        bounds: CGRect? = nil
    ) -> CGWindowSnapshot {
        CGWindowSnapshot(
            windowID: id,
            pid: pid,
            layer: layer,
            alpha: 1,
            bounds: bounds ?? windowBounds,
            isOnscreen: true
        )
    }
}
