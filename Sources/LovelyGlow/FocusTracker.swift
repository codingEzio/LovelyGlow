import AppKit
import ApplicationServices
import Foundation
import LovelyGlowCore

@MainActor
final class FocusTracker: NSObject {
    var onChange: ((FocusDecision) -> Void)?
    var onLiveResize: ((Bool) -> Void)?
    var overlayWindowIDs: Set<UInt32> = []
    var includeAuxiliaryWindows = false

    private var enabled = true
    private var spaceVisibility = SpaceVisibility()
    private var cachedApps: [RunningAppSnapshot] = []
    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var dragMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var lastDecision: FocusDecision?
    private var lastFlags: NSEvent.ModifierFlags = []
    private var overviewStickyUntil: Date?
    private var overviewWatch: Timer?
    private static let catchUpDelays: [TimeInterval] = [0.04, 0.10, 0.22, 0.45, 0.85]
    private var spaceRecoveryUntil: TimeInterval?
    private var catchUpGeneration = 0
    private var mouseDown = false
    private var pointerWindowID: UInt32?
    private var pointerLaggingID: UInt32?
    private var pointerUntil: Date?
    private var liveResize = false {
        didSet {
            if liveResize != oldValue {
                onLiveResize?(liveResize)
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled {
            start()
            refresh()
        } else {
            stop()
            publish(.hidden(.disabled))
        }
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(self, selector: #selector(workspaceChanged(_:)), name: name, object: nil)
        }
        cachedApps = readRunningApps()
        workspace.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        workspace.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
        workspace.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didHideApplicationNotification,
            object: nil
        )
        workspace.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didUnhideApplicationNotification,
            object: nil
        )
        workspace.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        installDragMonitor()
        installKeyMonitors()
        attachObserver(to: NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        detachObserver()
        removeDragMonitor()
        removeKeyMonitors()
        overviewWatch?.invalidate()
        overviewWatch = nil
        overviewStickyUntil = nil
        spaceRecoveryUntil = nil
        catchUpGeneration += 1
        mouseDown = false
        liveResize = false
        clearPointerIntent()
        spaceVisibility = SpaceVisibility()
    }

    func refresh() {
        let snapshots = CGWindowInventory.snapshots(fresh: true)
        refresh(snapshots: snapshots, apps: runningApps())
    }

    /// Display-link path: retarget as soon as CG z-order changes, without AX.
    func pollVisual() {
        guard enabled else { return }
        // One fresh snapshot supplies visibility and every overlay.
        refresh(snapshots: CGWindowInventory.snapshots(fresh: true), apps: runningApps(), allowAX: false)
    }

    private func refresh(snapshots: [CGWindowSnapshot], apps: [RunningAppSnapshot], allowAX: Bool = true) {
        let workspaceFront = NSWorkspace.shared.frontmostApplication
        let visual = chooseVisual(snapshots: snapshots, apps: apps)
        let frontApp =
            visual?.app
            ?? workspaceFront.map {
                RunningAppSnapshot(
                    pid: $0.processIdentifier,
                    bundleID: $0.bundleIdentifier,
                    name: $0.localizedName ?? "",
                    isHidden: $0.isHidden,
                    isRegular: $0.activationPolicy == .regular
                )
            }
        let observation = DesktopChrome.observation(
            windowBounds: visual?.window.bounds, windowID: visual?.window.windowID)
        let spaceHidden = spaceVisibility.shouldHide(observation)
        let stickyOverview = overviewStickyUntil.map { $0 > Date() } ?? false
        if !stickyOverview { overviewStickyUntil = nil }
        let missionControl = spaceHidden || stickyOverview
        if missionControl { clearPointerIntent() }
        let displays = CGWindowInventory.displays()
        let axWindow: AXWindowSnapshot?
        // AX focus may lag CG focus. Keep synchronous IPC out of normal hops.
        if allowAX, liveResize, !missionControl, let pid = frontApp?.pid, AccessibilityPermission.isTrusted {
            axWindow = AXWindowQuery.focusedWindow(for: pid)
        } else {
            axWindow = nil
        }
        let decision = FocusResolver.resolve(
            enabled: enabled,
            frontApp: frontApp,
            axWindow: axWindow,
            cgWindows: snapshots,
            displays: displays,
            ownBundleID: ProductIdentity.bundleID,
            overlayWindowIDs: overlayWindowIDs,
            missionControl: missionControl,
            runningApps: apps,
            preferredWindowID: pointerWindowID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )
        if case .visible = decision { spaceRecoveryUntil = nil }
        publish(decision)
        attachObserver(to: frontApp?.pid)
        updateOverviewWatch(
            front: workspaceFront,
            missionControl: observation.spaceType == SpaceOverview.systemSpace || spaceVisibility.needsConfirmation
                || stickyOverview)
    }

    private func publish(_ decision: FocusDecision) {
        if case .hold = decision { return }
        guard decision != lastDecision else { return }
        lastDecision = decision
        MotionDiagnostics.decision(decision)
        onChange?(decision)
    }

    @objc private func workspaceChanged(_ notification: Notification) {
        cachedApps = readRunningApps()
        if notification.name == NSApplication.didChangeScreenParametersNotification {
            DesktopChrome.invalidateDisplays()
        }
        if notification.name == NSWorkspace.activeSpaceDidChangeNotification {
            // The notification can precede settled CG bounds/membership. Keep
            // sampling briefly even when a stale fullscreen result stops rendering.
            spaceRecoveryUntil = ProcessInfo.processInfo.systemUptime + (Self.catchUpDelays.last ?? 0)
            clearPointerIntent()
            publish(.hidden(.missionControl))
        }
        refresh()
    }

    private func runningApps() -> [RunningAppSnapshot] {
        cachedApps
    }

    private func readRunningApps() -> [RunningAppSnapshot] {
        NSWorkspace.shared.runningApplications.map { app in
            RunningAppSnapshot(
                pid: app.processIdentifier,
                bundleID: app.bundleIdentifier,
                name: app.localizedName ?? "",
                isHidden: app.isHidden,
                isRegular: app.activationPolicy == .regular
            )
        }
    }

    private func attachObserver(to pid: pid_t?) {
        guard AccessibilityPermission.isTrusted, let pid, pid != observedPID else {
            if pid == nil { detachObserver() }
            return
        }
        detachObserver()
        var created: AXObserver?
        let result = AXObserverCreate(
            pid,
            { _, _, notification, refcon in
                guard let refcon else { return }
                let name = notification as String
                let tracker = Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async {
                    if name == kAXWindowMovedNotification as String
                        || name == kAXWindowResizedNotification as String
                    {
                        if tracker.liveResize {
                            tracker.refresh()
                        }
                        return
                    }
                    tracker.refresh()
                }
            },
            &created
        )
        guard result == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        let notifications = [
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXApplicationHiddenNotification,
            kAXUIElementDestroyedNotification,
        ]
        for notification in notifications {
            AXObserverAddNotification(
                created,
                app,
                notification as CFString,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    private func detachObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedPID = nil
    }

    private func installDragMonitor() {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [
                .leftMouseDown,
                .leftMouseDragged,
                .leftMouseUp,
                .rightMouseDown,
                .rightMouseDragged,
                .rightMouseUp,
            ]
        ) { [weak self] event in
            self?.handleMouse(event)
        }
    }

    private func removeDragMonitor() {
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
        dragMonitor = nil
    }

    private func handleMouse(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            if mouseIsOverOurUI() { return }
            mouseDown = true
            applyLiveResize(from: event)
            let snapshots = CGWindowInventory.snapshots(fresh: true)
            let apps = runningApps()
            capturePointerIntent(snapshots: snapshots, apps: apps)
            refresh(snapshots: snapshots, apps: apps)
        case .leftMouseUp, .rightMouseUp:
            mouseDown = false
            applyLiveResize(from: event)
            refresh()
        case .leftMouseDragged, .rightMouseDragged:
            mouseDown = true
            applyLiveResize(from: event)
            if liveResize {
                refresh()
            }
        default:
            break
        }
    }

    private var pointerIntentActive: Bool {
        pointerWindowID != nil
            && (mouseDown || (pointerUntil.map { $0 > Date() } ?? false))
    }

    private func capturePointerIntent(snapshots: [CGWindowSnapshot], apps: [RunningAppSnapshot]) {
        guard !mouseIsOverOurUI() else { return }
        guard let hit = hitVisual(snapshots: snapshots, apps: apps) else { return }
        let zOrder = FocusResolver.visualFront(
            cgWindows: snapshots,
            runningApps: apps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ProductIdentity.bundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )
        pointerWindowID = hit.window.windowID
        pointerLaggingID = zOrder?.window.windowID
        pointerUntil = Date().addingTimeInterval(0.85)
    }

    private func chooseVisual(
        snapshots: [CGWindowSnapshot],
        apps: [RunningAppSnapshot]
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        let zOrder = FocusResolver.visualFront(
            cgWindows: snapshots,
            runningApps: apps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ProductIdentity.bundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )
        guard pointerIntentActive, let preferredID = pointerWindowID else {
            clearPointerIntent()
            return zOrder
        }
        if !FocusResolver.shouldHoldPointer(
            preferredID: preferredID,
            laggingID: pointerLaggingID,
            zOrderID: zOrder?.window.windowID
        ) {
            clearPointerIntent()
            return zOrder
        }
        if let sticky = FocusResolver.visualWindow(
            id: preferredID,
            cgWindows: snapshots,
            runningApps: apps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ProductIdentity.bundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        ) {
            return sticky
        }
        if let hit = hitVisual(snapshots: snapshots, apps: apps) {
            pointerWindowID = hit.window.windowID
            return hit
        }
        clearPointerIntent()
        return zOrder
    }

    private func hitVisual(
        snapshots: [CGWindowSnapshot],
        apps: [RunningAppSnapshot]
    ) -> (app: RunningAppSnapshot, window: CGWindowSnapshot)? {
        FocusResolver.visualAt(
            point: WindowGeometry.cgPoint(
                fromCocoa: NSEvent.mouseLocation,
                primaryHeight: CGWindowInventory.primaryHeight()
            ),
            cgWindows: snapshots,
            runningApps: apps,
            overlayWindowIDs: overlayWindowIDs,
            ownBundleID: ProductIdentity.bundleID,
            includeAuxiliaryWindows: includeAuxiliaryWindows
        )
    }

    private func mouseIsOverOurUI() -> Bool {
        let point = NSEvent.mouseLocation
        return NSApp.windows.contains { window in
            window.isVisible && !window.ignoresMouseEvents && window.frame.contains(point)
        }
    }

    private func clearPointerIntent() {
        pointerWindowID = nil
        pointerLaggingID = nil
        pointerUntil = nil
    }

    private func applyLiveResize(from event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        liveResize = LiveWindowGesture.isOptionResize(
            optionDown: flags.contains(.option),
            commandDown: flags.contains(.command),
            mouseDown: mouseDown
        )
    }

    private func installKeyMonitors() {
        guard globalKeyMonitor == nil else { return }
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handleKey(event)
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged],
            handler: handler
        )
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
            [weak self] event in
            self?.handleKey(event)
            return event
        }
    }

    private func removeKeyMonitors() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        globalKeyMonitor = nil
        localKeyMonitor = nil
    }

    private func handleKey(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let wasCommand = lastFlags.contains(.command)
            let wasControl = lastFlags.contains(.control)
            let wasOption = lastFlags.contains(.option)
            lastFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            liveResize = LiveWindowGesture.isOptionResize(
                optionDown: lastFlags.contains(.option),
                commandDown: lastFlags.contains(.command),
                mouseDown: mouseDown
            )
            if (wasCommand && !event.modifierFlags.contains(.command))
                || (wasControl && !event.modifierFlags.contains(.control))
                || (wasOption && !event.modifierFlags.contains(.option))
                || liveResize
            {
                refresh()
                catchUp()
            }
            return
        }

        if isMissionControlChord(event) {
            if event.type == .keyDown {
                stickOverview()
            }
            refresh()
            catchUp()
            return
        }

        if isLayoutChord(event) {
            refresh()
            catchUp()
            return
        }

        let command = event.modifierFlags.contains(.command)
        if event.type == .keyUp, command, ShortcutKey.commandAppChords.contains(event.keyCode) {
            refresh()
            catchUp()
        }
    }

    private func isMissionControlChord(_ event: NSEvent) -> Bool {
        if event.keyCode == ShortcutKey.missionControl { return true }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return flags == [.control]
            && (event.keyCode == ShortcutKey.up || event.keyCode == ShortcutKey.down)
    }

    private func isLayoutChord(_ event: NSEvent) -> Bool {
        LiveWindowGesture.isLayoutModifier(
            controlDown: event.modifierFlags.contains(.control),
            optionDown: event.modifierFlags.contains(.option)
        )
    }

    private func stickOverview() {
        overviewStickyUntil = Date().addingTimeInterval(0.7)
    }

    private func catchUp() {
        catchUpGeneration += 1
        let generation = catchUpGeneration
        for delay in Self.catchUpDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, generation == self.catchUpGeneration else { return }
                self.refresh()
            }
        }
    }

    private func updateOverviewWatch(front: NSRunningApplication?, missionControl: Bool) {
        if let deadline = spaceRecoveryUntil, ProcessInfo.processInfo.systemUptime >= deadline {
            spaceRecoveryUntil = nil
        }
        let unsettled =
            missionControl
            || FocusResolver.isSystemChrome(front?.bundleIdentifier)
            || overviewStickyUntil != nil
            || spaceRecoveryUntil != nil
        if unsettled {
            if overviewWatch == nil {
                let hz = NSScreen.main?.maximumFramesPerSecond ?? 120
                let timer = Timer(timeInterval: 1 / Double(max(hz, 1)), repeats: true) { [weak self] _ in
                    DispatchQueue.main.async { self?.pollVisual() }
                }
                RunLoop.main.add(timer, forMode: .common)
                overviewWatch = timer
            }
        } else if let overviewWatch {
            overviewWatch.invalidate()
            self.overviewWatch = nil
        }
    }
}

private enum ShortcutKey {
    static let tab: UInt16 = 48
    static let grave: UInt16 = 50
    static let h: UInt16 = 4
    static let m: UInt16 = 46
    static let w: UInt16 = 13
    static let q: UInt16 = 12
    static let space: UInt16 = 49
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let missionControl: UInt16 = 160

    static let commandAppChords: Set<UInt16> = [tab, grave, h, m, w, q, space]
}
