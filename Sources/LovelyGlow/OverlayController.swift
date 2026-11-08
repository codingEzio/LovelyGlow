import AppKit
import LovelyGlowCore
import QuartzCore

@MainActor
final class OverlayController {
    var onVisualPoll: (() -> Void)?
    var liveResize = false

    private var slots: [SlotKey: OverlaySlot] = [:]
    private var spare: [OverlaySlot] = []
    private var style = GlowStyle.default
    private var scheme: GlowSchemeID = .violetBloom
    private var animation: GlowAnimationID = .orbitBreathe
    private var speed: CGFloat = GlowMotion.defaultSpeed
    private var arrival: GlowArrivalID = .instant
    private var cachedChrome: [CGRect] = []
    private var cachedScreens: [CGRect] = []
    private var frameGate = FrameGate()

    var windowIDs: Set<UInt32> {
        Set(slots.values.map(\.windowID) + spare.map(\.windowID))
    }

    func prepare() {
        _ = GlowMetalRenderer.shared
        if spare.isEmpty {
            spare.append(OverlaySlot())
        }
        refreshChrome()
    }

    func applySettings(
        style: GlowStyle,
        scheme: GlowSchemeID,
        animation: GlowAnimationID,
        speed: CGFloat,
        arrival: GlowArrivalID
    ) {
        self.style = style
        self.scheme = scheme
        self.animation = animation
        self.speed = speed
        self.arrival = arrival
        refreshChrome()
        for slot in slots.values {
            if let window = slot.lastWindow {
                slot.show(
                    window,
                    style: style,
                    settings: viewSettings(role: slot.role),
                    chrome: cachedChrome,
                    screens: cachedScreens,
                    morphFrom: nil
                )
            } else {
                slot.glowView.updateSettings(viewSettings(role: slot.role))
            }
        }
    }

    func updateAboveDock(_ aboveDock: Bool) {
        let level = OverlayWindowFactory.level(aboveDock: aboveDock)
        for slot in slots.values + spare {
            slot.panel.level = level
            if slot.visible {
                slot.panel.orderFrontRegardless()
            }
        }
    }

    func apply(_ decision: FocusDecision) {
        switch decision {
        case .hidden:
            hideAll()
        case .visible(let presentation):
            show(presentation)
        case .hold:
            break
        }
    }

    private func show(_ presentation: GlowPresentation) {
        refreshChrome()
        var unused = Set(slots.keys)
        let previousFocused = slots.first { $0.value.role == .focused }
        for target in presentation.targets {
            let key = SlotKey(pid: target.window.pid, windowID: target.window.cgWindowID ?? 0)
            unused.remove(key)
            let slot: OverlaySlot
            if let existing = slots[key] {
                slot = existing
            } else if target.role == .focused, let previous = previousFocused {
                slots.removeValue(forKey: previous.key)
                unused.remove(previous.key)
                slot = previous.value
            } else {
                slot = takeSpare()
            }
            slots[key] = slot
            slot.role = target.role
            slot.onFrame = { [weak self, weak slot] time, delta in
                guard let self, let slot else { return }
                self.pollVisualOnce(time: time, screen: slot.panel.screen)
                guard slot.visible else { return }
                self.follow(slot, time: time, delta: delta)
            }
            slot.show(
                target.window,
                style: style,
                settings: viewSettings(for: target),
                chrome: cachedChrome,
                screens: cachedScreens,
                morphFrom: target.role == .focused ? previousFocused?.value.lastWindowCocoa : nil
            )
        }
        for key in unused {
            if let slot = slots.removeValue(forKey: key) {
                slot.hide()
                if spare.count < 4 {
                    spare.append(slot)
                }
            }
        }
    }

    private func pollVisualOnce(time: CFTimeInterval, screen: NSScreen?) {
        let displayID =
            (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        guard frameGate.consume(time, displayID: displayID) else { return }
        onVisualPoll?()
    }

    private func follow(_ slot: OverlaySlot, time: CFTimeInterval, delta: CFTimeInterval) {
        if let window = slot.lastWindow {
            let cgBounds = WindowFollow.bounds(for: window, in: CGWindowInventory.currentSnapshots)
            let bounds: CGRect?
            if liveResize, window.trackingWindowIDs.count == 1, let ax = AXWindowQuery.focusedWindow(for: window.pid) {
                bounds = FocusResolver.liveResizeBounds(ax: ax.bounds, cg: cgBounds ?? window.bounds)
            } else {
                bounds = cgBounds
            }
            if let bounds, bounds != window.bounds {
                var next = window
                next.bounds = bounds
                slot.updateTarget(next)
            }
        }
        slot.advance(
            time: time,
            delta: delta,
            style: style,
            settings: viewSettings(role: slot.role),
            chrome: cachedChrome,
            screens: cachedScreens
        )
    }

    private func hideAll() {
        for key in Array(slots.keys) {
            if let slot = slots.removeValue(forKey: key) {
                slot.hide()
                if spare.count < 4 {
                    spare.append(slot)
                }
            }
        }
    }

    private func takeSpare() -> OverlaySlot {
        spare.popLast() ?? OverlaySlot()
    }

    private func refreshChrome() {
        cachedChrome = CGWindowInventory.chromeFrames()
        cachedScreens = NSScreen.screens.map(\.frame)
    }

    private func viewSettings(for target: GlowTarget) -> GlowViewSettings {
        GlowViewSettings(
            style: style,
            scheme: target.schemeID ?? scheme,
            animation: target.animationID ?? animation,
            speed: speed,
            role: target.role,
            arrival: arrival
        )
    }

    private func viewSettings(role: GlowTargetRole) -> GlowViewSettings {
        GlowViewSettings(
            style: style,
            scheme: scheme,
            animation: animation,
            speed: speed,
            role: role,
            arrival: arrival
        )
    }
}

@MainActor
private final class OverlaySlot {
    let panel: OverlayPanel
    let glowView = GlowView()
    var visible = false
    var role: GlowTargetRole = .focused
    var onFrame: ((CFTimeInterval, CFTimeInterval) -> Void)?
    private(set) var lastWindow: FocusedWindow?
    private(set) var lastWindowCocoa: CGRect?
    private(set) var isTraveling = false
    private var hideGeneration = 0
    private var lastIdentity: FocusIdentity?
    private var lastSettings: GlowViewSettings?
    private var lastReportedCornerRadius: CGFloat?
    private var travel: GlowTravelState?
    private var travelSize: CGSize?
    private var lastFrameTime: CFTimeInterval?
    private var presentedCocoa: CGRect?

    var windowID: UInt32 {
        WindowGeometry.cgWindowID(fromWindowNumber: panel.windowNumber) ?? 0
    }

    init() {
        panel = OverlayWindowFactory.makePanel()
        panel.contentView = glowView
        glowView.onFrame = { [weak self] time, delta in
            self?.onFrame?(time, delta)
        }
    }

    func updateTarget(_ window: FocusedWindow) {
        lastWindow = window
    }

    func show(
        _ window: FocusedWindow,
        style: GlowStyle,
        settings: GlowViewSettings,
        chrome: [CGRect],
        screens: [CGRect],
        morphFrom: CGRect?
    ) {
        hideGeneration += 1
        lastWindow = window
        let primaryHeight = CGWindowInventory.primaryHeight()
        let windowCocoa = WindowGeometry.cocoaFrame(fromCG: window.bounds, primaryHeight: primaryHeight)
        if lastWindowCocoa?.size != windowCocoa.size {
            WindowCornerQuery.forget(window.cgWindowID)
        }
        let drawing = style.withReportedCornerRadius(WindowCornerQuery.radius(for: window.cgWindowID))
        let identity = FocusIdentity(pid: window.pid, windowID: window.cgWindowID)
        let identityChanged = lastIdentity != identity
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let canTravel = settings.arrival == .seamless && !reducedMotion
        if settings.arrival == .instant || reducedMotion {
            travel = nil
            travelSize = nil
            lastFrameTime = nil
            isTraveling = false
            if identityChanged {
                glowView.clearArrive()
            }
        } else if identityChanged {
            if canTravel, visible, let from = presentedCocoa ?? lastWindowCocoa ?? morphFrom, from != windowCocoa {
                if travel == nil {
                    travel = .at(from)
                }
                if let current = travel {
                    travel = GlowTravel.retarget(current, to: windowCocoa)
                }
                let pad = OverlayGeometry.pad(for: drawing)
                let needed = GlowTravel.drawableSize(from: from, to: windowCocoa, pad: pad)
                travelSize = GlowTravel.grow(travelSize ?? needed, to: needed)
                glowView.clearArrive()
            } else if canTravel, !visible {
                travel = nil
                travelSize = nil
                lastFrameTime = nil
                glowView.playArrive(reducedMotion: reducedMotion)
            } else {
                travel = nil
                travelSize = nil
                lastFrameTime = nil
                glowView.clearArrive()
            }
        } else if canTravel, let travel {
            let pad = OverlayGeometry.pad(for: drawing)
            let from = travel.rect
            let needed = GlowTravel.drawableSize(from: from, to: windowCocoa, pad: pad)
            travelSize = GlowTravel.grow(travelSize ?? needed, to: needed)
        }
        present(
            windowCocoa: windowCocoa,
            style: drawing,
            settings: settings,
            chrome: chrome,
            screens: screens,
            identity: identity,
            time: nil
        )
    }

    func advance(
        time: CFTimeInterval,
        delta: CFTimeInterval,
        style: GlowStyle,
        settings: GlowViewSettings,
        chrome: [CGRect],
        screens: [CGRect]
    ) {
        guard let window = lastWindow else { return }
        var drawing = style
        drawing.cornerRadius =
            lastReportedCornerRadius
            ?? drawing.cornerRadius
        let primaryHeight = CGWindowInventory.primaryHeight()
        let windowCocoa = WindowGeometry.cocoaFrame(fromCG: window.bounds, primaryHeight: primaryHeight)
        let identity = FocusIdentity(pid: window.pid, windowID: window.cgWindowID)
        present(
            windowCocoa: windowCocoa,
            style: drawing,
            settings: settings,
            chrome: chrome,
            screens: screens,
            identity: identity,
            time: time,
            delta: delta
        )
    }

    private func present(
        windowCocoa: CGRect,
        style: GlowStyle,
        settings: GlowViewSettings,
        chrome: [CGRect],
        screens: [CGRect],
        identity: FocusIdentity,
        time: CFTimeInterval?,
        delta: CFTimeInterval = 0
    ) {
        let drawnCocoa: CGRect
        var traveling = false
        if var travel, settings.arrival == .seamless {
            if let time {
                let dt = lastFrameTime.map { time - $0 } ?? delta
                travel = GlowTravel.step(state: travel, target: windowCocoa, dt: dt)
                lastFrameTime = time
                self.travel = travel
            }
            drawnCocoa = travel.rect
            traveling = !GlowTravel.isSettled(travel, target: windowCocoa)
            if !traveling {
                self.travel = nil
                travelSize = nil
                lastFrameTime = nil
            } else {
                let pad = OverlayGeometry.pad(for: style)
                let needed = GlowTravel.drawableSize(from: travel.rect, to: windowCocoa, pad: pad)
                travelSize = GlowTravel.grow(travelSize ?? needed, to: needed)
            }
        } else {
            drawnCocoa = windowCocoa
            travel = nil
            travelSize = nil
            lastFrameTime = nil
        }
        isTraveling = traveling
        let destination = OverlayGeometry.slackFrame(windowCocoa: windowCocoa, style: style)
        let nextFrame: CGRect
        if traveling, let travelSize {
            nextFrame = GlowTravel.panelFrame(drawn: drawnCocoa, size: travelSize)
        } else {
            nextFrame = destination
        }
        let sizeChanged = lastWindowCocoa?.size != windowCocoa.size
        let settingsChanged = lastSettings != settings || lastReportedCornerRadius != style.cornerRadius
        let needsRelayout = OverlayGeometry.needsEdgeRelayout(
            windowCocoa: drawnCocoa,
            previous: presentedCocoa,
            chrome: chrome,
            screens: screens,
            pad: OverlayGeometry.pad(for: style)
        )
        if panel.frame.size == nextFrame.size, panel.frame.origin != nextFrame.origin {
            rebaseOrigin(to: nextFrame.origin)
        } else if panel.frame != nextFrame {
            rebase(to: nextFrame)
        }
        if !visible || sizeChanged || settingsChanged || needsRelayout || traveling
            || presentedCocoa != drawnCocoa
        {
            paint(windowCocoa: drawnCocoa, style: style, settings: settings, chrome: chrome, screens: screens)
        }
        lastIdentity = identity
        lastWindowCocoa = windowCocoa
        presentedCocoa = drawnCocoa
        lastSettings = settings
        lastReportedCornerRadius = style.cornerRadius
        if !visible {
            panel.alphaValue = OverlaySafety.shownAlpha
            panel.orderFrontRegardless()
            visible = true
        }
        glowView.setDisplayLinkEnabled(true)
    }

    private func paint(
        windowCocoa: CGRect,
        style: GlowStyle,
        settings: GlowViewSettings,
        chrome: [CGRect],
        screens: [CGRect]
    ) {
        glowView.apply(
            layout: OverlayGeometry.aligned(
                windowCocoa: windowCocoa,
                panelFrame: panel.frame,
                style: style,
                occludersCocoa: chrome,
                screensCocoa: screens
            ),
            settings: settings
        )
    }

    private func rebase(to frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(frame, display: false)
        CATransaction.commit()
    }

    private func rebaseOrigin(to origin: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrameOrigin(origin)
        CATransaction.commit()
    }

    func hide() {
        glowView.setDisplayLinkEnabled(false)
        glowView.clearArrive()
        WindowCornerQuery.forget(lastWindow?.cgWindowID)
        lastIdentity = nil
        lastWindowCocoa = nil
        presentedCocoa = nil
        travel = nil
        travelSize = nil
        lastFrameTime = nil
        isTraveling = false
        lastWindow = nil
        lastSettings = nil
        lastReportedCornerRadius = nil
        hideGeneration += 1
        guard visible || panel.isVisible else { return }
        panel.alphaValue = OverlaySafety.hiddenAlpha
        panel.orderOut(nil)
        visible = false
    }
}

private struct SlotKey: Hashable {
    var pid: Int32
    var windowID: UInt32
}

private struct FocusIdentity: Equatable {
    var pid: Int32
    var windowID: UInt32?
}
