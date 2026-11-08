import AppKit
import LovelyGlowCore
import SwiftUI

enum GlowImmediateMainAction {
    static func invoke(_ action: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(action)
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}

@MainActor
private final class GlowOutsideClickMonitor {
    private static let eventMask: NSEvent.EventTypeMask = [
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
    ]

    private let shouldDismissLocalEvent: (NSEvent) -> Bool
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(shouldDismissLocalEvent: @escaping (NSEvent) -> Bool) {
        self.shouldDismissLocalEvent = shouldDismissLocalEvent
    }

    var activeMonitorCount: Int {
        (globalMonitor == nil ? 0 : 1) + (localMonitor == nil ? 0 : 1)
    }

    func start(_ handler: @escaping @MainActor @Sendable () -> Void) {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.eventMask) { _ in
            GlowImmediateMainAction.invoke(handler)
        }
        let shouldDismissLocalEvent = shouldDismissLocalEvent
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.eventMask) { event in
            if shouldDismissLocalEvent(event) {
                GlowImmediateMainAction.invoke(handler)
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}

@MainActor
private final class GlowPanelHostController: NSHostingController<GlowPanelView> {
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private static let activationEvents: NSEvent.EventTypeMask = .leftMouseDown

    private let runtime: GlowRuntime
    private let model: GlowPanelModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let host: GlowPanelHostController
    private let outsideClickMonitor: GlowOutsideClickMonitor
    private var dismissalGuardTimer: Timer?

    init(runtime: GlowRuntime) {
        self.runtime = runtime
        let model = GlowPanelModel(runtime: runtime)
        self.model = model
        let host = GlowPanelHostController(rootView: GlowPanelView(model: model))
        self.host = host
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        outsideClickMonitor = GlowOutsideClickMonitor { event in
            GlowPopoverDismissal.shouldDismiss(
                clickedPanel: event.window === host.view.window,
                clickedStatusItem: event.window === statusItem.button?.window,
                clickedMenu: event.window?.level == .popUpMenu
            )
        }
        super.init()

        popover.behavior = .applicationDefined
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.delegate = self
        host.sizingOptions = [.preferredContentSize]
        host.onCancel = { [weak self] in
            self?.closePopover()
        }
        GlowPanelHost.applyOpaqueCard(to: host.view)
        popover.contentViewController = host

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = ProductIdentity.displayName
            button.setAccessibilityLabel(ProductIdentity.displayName)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: Self.activationEvents)
        }
        statusItem.isVisible = true
        model.onLayoutChange = { [weak self] in
            self?.syncPopoverSize()
        }
        updateIcon()
    }

    var isPopoverShown: Bool { popover.isShown }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        runtime.refreshAccessibility()
        model.refreshAccessibility()
        host.rootView = GlowPanelView(model: model)
        syncPopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        guard popover.isShown else { return }
        popover.contentViewController?.view.window?.allowsToolTipsWhenApplicationIsInactive = true
        if let window = popover.contentViewController?.view.window {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
        GlowPanelHost.applyOpaqueCard(to: host.view)
        armOutsideClickMonitor()
        startDismissalGuard()
        updateIcon()
    }

    func closePopover() {
        guard popover.isShown else {
            cleanupPresentation()
            return
        }
        popover.performClose(nil)
        if popover.isShown {
            popover.close()
        }
        if popover.isShown {
            popover.contentViewController?.view.window?.orderOut(nil)
        }
        if !popover.isShown {
            cleanupPresentation()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        cleanupPresentation()
    }

    func updateIcon() {
        statusItem.button?.image = StatusIcon.image(enabled: runtime.store.document.enabled)
    }

    private func syncPopoverSize() {
        host.view.layoutSubtreeIfNeeded()
        let fitted = host.view.fittingSize
        popover.contentSize = NSSize(
            width: GlowPanelMetrics.width,
            height: max(fitted.height, 220)
        )
    }

    private func armOutsideClickMonitor() {
        outsideClickMonitor.start { [weak self] in
            self?.closePopover()
        }
    }

    private func startDismissalGuard() {
        stopDismissalGuard()
        let action: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self, self.popover.isShown else { return }
            if self.outsideClickMonitor.activeMonitorCount == 0 {
                self.armOutsideClickMonitor()
            }
        }
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            GlowImmediateMainAction.invoke(action)
        }
        RunLoop.main.add(timer, forMode: .common)
        dismissalGuardTimer = timer
    }

    private func stopDismissalGuard() {
        dismissalGuardTimer?.invalidate()
        dismissalGuardTimer = nil
    }

    private func cleanupPresentation() {
        stopDismissalGuard()
        outsideClickMonitor.stop()
        updateIcon()
    }
}