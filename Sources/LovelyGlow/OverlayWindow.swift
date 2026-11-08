import AppKit
import LovelyGlowCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
enum OverlayWindowFactory {
    static func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = OverlayWindowFactory.level(aboveDock: true)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isExcludedFromWindowsMenu = true
        panel.sharingType = .none
        panel.alphaValue = OverlaySafety.hiddenAlpha
        panel.collectionBehavior = [
            // Never composite the rim into both sides of a fullscreen swipe.
            .moveToActiveSpace,
            .ignoresCycle,
            .transient,
        ]
        panel.animationBehavior = .none
        return panel
    }

    static func level(aboveDock: Bool) -> NSWindow.Level {
        NSWindow.Level(rawValue: Int(OverlaySafety.overlayLevel(aboveDock: aboveDock)))
    }
}
