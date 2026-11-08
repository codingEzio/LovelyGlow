import CoreGraphics
import Foundation

public enum FocusResolver {
    public static let minimumWindowSize = CGSize(width: 80, height: 60)
    public static let displayFillRatio: CGFloat = 0.985
    public static let visibleFillRatio: CGFloat = 0.96
    public static let nearlyFullscreenRatio: CGFloat = 0.9
    public static let axFullscreenRatio: CGFloat = 0.8
    public static let defaultOwnBundleID = OverlaySafety.ownBundleID

    public static let skippedBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.CoreServicesUIAgent",
        "com.apple.dock",
        "com.apple.dock.extra",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.OSDUIHelper",
        "com.apple.PIPAgent",
        "com.apple.screencaptureui",
        "com.apple.Spotlight",
        "com.apple.SystemUIServer",
        "com.apple.TextInputMenuAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.wallpaper.agent",
        "com.apple.WindowManager",
    ]

    public static func resolve(
        enabled: Bool,
        frontApp: RunningAppSnapshot?,
        axWindow: AXWindowSnapshot?,
        cgWindows: [CGWindowSnapshot],
        displays: [DisplaySnapshot],
        ownBundleID: String = defaultOwnBundleID,
        overlayWindowIDs: Set<UInt32> = [],
        missionControl: Bool = false,
        runningApps: [RunningAppSnapshot] = [],
        preferredWindowID: UInt32? = nil,
        includeAuxiliaryWindows: Bool = false
    ) -> FocusDecision {
        guard enabled else { return .hidden(.disabled) }
        guard !ownBundleID.isEmpty else { return .hidden(.noFrontApp) }
        if missionControl { return .hidden(.missionControl) }
        guard let frontApp else { return .hidden(.noFrontApp) }

        if let bundleID = frontApp.bundleID, bundleID == ownBundleID {
            return .hold
        }
        if isSystemChrome(frontApp.bundleID) {
            return .hold
        }

        if frontApp.isHidden {
            if let next = nextVisibleApp(
                after: frontApp,
                in: runningApps,
                cgWindows: cgWindows,
                overlayWindowIDs: overlayWindowIDs,
                ownBundleID: ownBundleID,
                includeAuxiliaryWindows: includeAuxiliaryWindows
            ) {
                return resolve(
                    enabled: enabled,
                    frontApp: next,
                    axWindow: nil,
                    cgWindows: cgWindows,
                    displays: displays,
                    ownBundleID: ownBundleID,
                    overlayWindowIDs: overlayWindowIDs,
                    missionControl: false,
                    runningApps: runningApps.filter { $0.pid != frontApp.pid },
                    preferredWindowID: preferredWindowID,
                    includeAuxiliaryWindows: includeAuxiliaryWindows
                )
            }
            return .hidden(.hiddenApp)
        }

        var candidates = cgCandidates(
            pid: frontApp.pid,
            windows: cgWindows,
            overlayWindowIDs: overlayWindowIDs,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )

        if let preferredID = preferredWindowID,
            let preferred = candidates.first(where: { $0.windowID == preferredID })
        {
            if isFullscreen(preferred.bounds, displays: displays) {
                return .hidden(.fullscreen)
            }
            return .glowing(
                FocusedWindow(
                    pid: frontApp.pid,
                    bundleID: frontApp.bundleID,
                    cgWindowID: preferred.windowID,
                    bounds: preferred.bounds
                )
            )
        }

        if let axWindow, axWindow.pid == frontApp.pid {
            if axWindow.isMinimized {
                candidates = candidates.filter { !isSameWindow($0.bounds, axWindow.bounds) }
                if candidates.isEmpty { return .hidden(.minimized) }
            } else if isUsableSize(axWindow.bounds) {
                let chrome = outerChrome(ax: axWindow.bounds, candidates: candidates)
                if isFullscreen(chrome.bounds, displays: displays)
                    || (axWindow.isFullscreen
                        && fillsAnyDisplay(chrome.bounds, displays: displays, ratio: axFullscreenRatio))
                {
                    return .hidden(.fullscreen)
                }
                return .glowing(
                    FocusedWindow(
                        pid: frontApp.pid,
                        bundleID: frontApp.bundleID,
                        cgWindowID: chrome.windowID,
                        bounds: chrome.bounds
                    )
                )
            }
        }

        guard let chosen = candidates.first else { return .hidden(.noWindow) }
        if isFullscreen(chosen.bounds, displays: displays) {
            return .hidden(.fullscreen)
        }
        return .glowing(
            FocusedWindow(
                pid: frontApp.pid,
                bundleID: frontApp.bundleID,
                cgWindowID: chosen.windowID,
                bounds: chosen.bounds
            )
        )
    }

    public static func isSystemChrome(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return skippedBundleIDs.contains(bundleID)
    }

    /// Frontmost regular app by CG z-order. Looks through Dock, Spotlight, and our
    /// overlay so a trackpad click is visible before NSWorkspace catches up.
    public static func visualFront(
        cgWindows: [CGWindowSnapshot],
        runningApps: [RunningAppSnapshot],
        overlayWindowIDs: Set<UInt32>,
        ownBundleID: String,
        skipping skipPID: Int32? = nil,
        includeAuxiliaryWindows: Bool = false
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        visualMatch(
            cgWindows: cgWindows,
            runningApps: runningApps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ownBundleID,
            skipping: skipPID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        ) { _ in true }
    }

    /// Topmost regular window under a CG point. Use this on mouse-down so a click
    /// on a back window is not stuck on the previous z-order front.
    public static func visualAt(
        point: CGPoint,
        cgWindows: [CGWindowSnapshot],
        runningApps: [RunningAppSnapshot],
        overlayWindowIDs: Set<UInt32>,
        ownBundleID: String,
        includeAuxiliaryWindows: Bool = false
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        visualMatch(
            cgWindows: cgWindows,
            runningApps: runningApps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ownBundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        ) { window in
            window.bounds.insetBy(dx: -1, dy: -1).contains(point)
        }
    }

    public static func visualWindow(
        id: UInt32,
        cgWindows: [CGWindowSnapshot],
        runningApps: [RunningAppSnapshot],
        overlayWindowIDs: Set<UInt32>,
        ownBundleID: String,
        includeAuxiliaryWindows: Bool = false
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        visualMatch(
            cgWindows: cgWindows,
            runningApps: runningApps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ownBundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        ) { window in
            window.windowID == id
        }
    }

    /// Keep the mouse-down window while CG z-order still reports the previous front.
    public static func shouldHoldPointer(
        preferredID: UInt32,
        laggingID: UInt32?,
        zOrderID: UInt32?
    ) -> Bool {
        if zOrderID == preferredID { return false }
        if let zOrderID, zOrderID != preferredID {
            if laggingID == nil || zOrderID != laggingID {
                return false
            }
        }
        return true
    }

    /// Bounds jitter is overlay follow, not a new hop.
    public static func visualIdentityChanged(
        lastID: UInt32?,
        lastPID: Int32?,
        visualID: UInt32?,
        visualPID: Int32?
    ) -> Bool {
        visualID != lastID || visualPID != lastPID
    }

    private static func visualMatch(
        cgWindows: [CGWindowSnapshot],
        runningApps: [RunningAppSnapshot],
        overlayWindowIDs: Set<UInt32>,
        ownBundleID: String,
        skipping skipPID: Int32? = nil,
        includeAuxiliaryWindows: Bool = false,
        where matches: (CGWindowSnapshot) -> Bool
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        let byPID = Dictionary(runningApps.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        for window in cgWindows {
            if let skipPID, window.pid == skipPID { continue }
            guard matches(window) else { continue }
            guard window.layer == 0, window.alpha > 0.05, window.isOnscreen else { continue }
            guard !overlayWindowIDs.contains(window.windowID) else { continue }
            guard isUsableSize(window.bounds) else { continue }
            if !includeAuxiliaryWindows && isAuxiliary(window, among: cgWindows) { continue }
            guard let app = byPID[window.pid] else { continue }
            if app.isHidden || !app.isRegular { continue }
            if let bundleID = app.bundleID {
                if bundleID == ownBundleID { continue }
                if skippedBundleIDs.contains(bundleID) { continue }
            }
            return (app, window)
        }
        return nil
    }

    public static func nextVisibleApp(
        after hidden: RunningAppSnapshot,
        in apps: [RunningAppSnapshot],
        cgWindows: [CGWindowSnapshot],
        overlayWindowIDs: Set<UInt32>,
        ownBundleID: String,
        includeAuxiliaryWindows: Bool = false
    ) -> RunningAppSnapshot? {
        visualFront(
            cgWindows: cgWindows,
            runningApps: apps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ownBundleID,
            skipping: hidden.pid,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )?.app
    }

    public static func isUsableSize(_ bounds: CGRect) -> Bool {
        bounds.width >= minimumWindowSize.width && bounds.height >= minimumWindowSize.height
    }

    public static func isFullscreen(_ bounds: CGRect, displays: [DisplaySnapshot]) -> Bool {
        displays.contains { display in
            fills(bounds, of: display.bounds, ratio: displayFillRatio)
                || fills(bounds, of: display.visible, ratio: visibleFillRatio)
                || coversDisplayIgnoringMenuBar(bounds, display: display)
        }
    }

    public static func isNearlyFullscreen(_ bounds: CGRect?, displays: [DisplaySnapshot]) -> Bool {
        guard let bounds else { return false }
        return displays.contains { display in
            fills(bounds, of: display.bounds, ratio: nearlyFullscreenRatio)
                || fills(bounds, of: display.visible, ratio: nearlyFullscreenRatio)
        }
    }

    public static func isDisplayFilling(_ bounds: CGRect, displays: [DisplaySnapshot]) -> Bool {
        displays.contains { fills(bounds, of: $0.bounds, ratio: displayFillRatio) }
    }

    public static func isVisibleFilling(_ bounds: CGRect, displays: [DisplaySnapshot]) -> Bool {
        displays.contains { display in
            let distinct =
                abs(display.visible.width - display.bounds.width) > 1
                || abs(display.visible.height - display.bounds.height) > 1
            guard distinct else { return false }
            return fills(bounds, of: display.visible, ratio: visibleFillRatio)
        }
    }

    /// Native fullscreen often leaves a menu-bar strip; treat that as fullscreen too.
    public static func coversDisplayIgnoringMenuBar(_ bounds: CGRect, display: DisplaySnapshot) -> Bool {
        let widthOK =
            abs(bounds.width - display.bounds.width) <= 6
            || abs(bounds.width - display.visible.width) <= 6
        let heightOK =
            bounds.height >= display.bounds.height - 44
            || bounds.height >= display.visible.height - 4
        let xOK =
            abs(bounds.minX - display.bounds.minX) <= 6
            || abs(bounds.minX - display.visible.minX) <= 6
        let top = min(display.bounds.minY, display.visible.minY)
        let topOK =
            bounds.minY <= top + 8
            || abs(bounds.minY - display.bounds.minY) <= 8
            || abs(bounds.minY - display.visible.minY) <= 8
        return widthOK && heightOK && xOK && topOK
    }

    public static func fillsAnyDisplay(_ bounds: CGRect, displays: [DisplaySnapshot], ratio: CGFloat) -> Bool {
        displays.contains { display in
            fills(bounds, of: display.bounds, ratio: ratio)
                || fills(bounds, of: display.visible, ratio: ratio)
        }
    }

    private static func fills(_ bounds: CGRect, of space: CGRect, ratio: CGFloat) -> Bool {
        let area = space.area
        guard area > 0 else { return false }
        return space.intersection(bounds).area / area >= ratio
    }

    public static func cgCandidates(
        pid: Int32,
        windows: [CGWindowSnapshot],
        overlayWindowIDs: Set<UInt32>,
        includeAuxiliaryWindows: Bool = false
    ) -> [CGWindowSnapshot] {
        windows.filter { window in
            window.pid == pid
                && window.layer == 0
                && window.alpha > 0.05
                && window.isOnscreen
                && !overlayWindowIDs.contains(window.windowID)
                && isUsableSize(window.bounds)
                && (includeAuxiliaryWindows || !isAuxiliary(window, among: windows))
        }
    }

    /// Chrome hover cards and similar app-owned popovers are usually small
    /// windows within a much larger window of the same process. This is a
    /// geometry fallback because CGWindowList does not expose an AX subrole.
    public static func isAuxiliary(_ window: CGWindowSnapshot, among windows: [CGWindowSnapshot]) -> Bool {
        if let name = window.name, !name.isEmpty { return false }
        return windows.contains { parent in
            guard parent.windowID != window.windowID, parent.pid == window.pid,
                parent.layer == 0, parent.isOnscreen, parent.alpha > 0.05,
                parent.bounds.area > 0, window.bounds.area < parent.bounds.area * 0.35,
                window.bounds.width < parent.bounds.width * 0.75,
                window.bounds.height < parent.bounds.height * 0.65
            else { return false }
            return parent.bounds.insetBy(dx: -24, dy: -24).contains(window.bounds)
        }
    }

    public static func outerChrome(
        ax: CGRect,
        candidates: [CGWindowSnapshot]
    ) -> (windowID: UInt32?, bounds: CGRect) {
        let chrome = candidates.filter { isTitlebarChrome(inner: ax, outer: $0.bounds) }
        if let outer = chrome.min(by: { $0.bounds.area < $1.bounds.area }) {
            return (outer.windowID, outer.bounds)
        }
        let matchedID = bestMatchingWindowID(ax, in: candidates)
        let cg = candidates.first(where: { $0.windowID == matchedID })?.bounds
        return (matchedID, drawingBounds(ax: ax, cg: cg))
    }

    public static func isTitlebarChrome(inner: CGRect, outer: CGRect) -> Bool {
        guard inner.width > 0, inner.height > 0, outer.width > 0, outer.height > 0 else { return false }
        let widthDelta = abs(inner.width - outer.width)
        let xDelta = abs(inner.minX - outer.minX)
        let heightDelta = outer.height - inner.height
        let topInset = inner.minY - outer.minY
        return outer.insetBy(dx: -2, dy: -2).contains(inner)
            && widthDelta <= 20
            && xDelta <= 20
            && heightDelta >= 8
            && heightDelta <= 100
            && topInset >= 0
            && topInset <= 100
    }

    public static func isSameWindow(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 8
            && abs(a.minY - b.minY) <= 8
            && abs(a.width - b.width) <= 8
            && abs(a.height - b.height) <= 8
    }

    public static func distinctWindows(_ windows: [CGWindowSnapshot]) -> [CGWindowSnapshot] {
        let sorted = windows.sorted { $0.bounds.area > $1.bounds.area }
        var kept: [CGWindowSnapshot] = []
        for window in sorted {
            let redundant = kept.contains { outer in
                isSameWindow(outer.bounds, window.bounds)
                    || isTitlebarChrome(inner: window.bounds, outer: outer.bounds)
            }
            if !redundant {
                kept.append(window)
            }
        }
        return kept
    }

    public static func drawingBounds(ax: CGRect, cg: CGRect?) -> CGRect {
        guard let cg else { return ax }
        let overlap = ax.intersection(cg).area
        let smaller = min(ax.area, cg.area)
        guard smaller > 0, overlap > smaller * 0.5 else { return ax }
        return trackingBounds(ax: ax, cg: cg)
    }

    public static func trackingBounds(ax: CGRect, cg: CGRect) -> CGRect {
        if similarSize(ax, cg) {
            return similarOrigin(ax, cg) ? ax.union(cg) : cg
        }
        if isTitlebarChrome(inner: ax, outer: cg) {
            return cg
        }
        if isTitlebarChrome(inner: cg, outer: ax) {
            return ax
        }
        return cg
    }

    /// Option-drag resize: AX usually has the live size; CG is usually live on move.
    public static func liveResizeBounds(ax: CGRect, cg: CGRect) -> CGRect {
        let sizeDelta = abs(ax.width - cg.width) + abs(ax.height - cg.height)
        if sizeDelta > 1 {
            return ax
        }
        return trackingBounds(ax: ax, cg: cg)
    }

    public static func similarSize(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.width - b.width) <= 8 && abs(a.height - b.height) <= 8
    }

    public static func similarOrigin(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 6 && abs(a.minY - b.minY) <= 6
    }

    public static func bestMatchingWindowID(_ bounds: CGRect, in windows: [CGWindowSnapshot]) -> UInt32? {
        let targetArea = bounds.area
        guard targetArea > 0 else { return windows.first?.windowID }
        return windows.max { lhs, rhs in
            lhs.bounds.intersection(bounds).area < rhs.bounds.intersection(bounds).area
        }.flatMap { window in
            window.bounds.intersection(bounds).area > targetArea * 0.35 ? window.windowID : nil
        } ?? windows.first?.windowID
    }
}
