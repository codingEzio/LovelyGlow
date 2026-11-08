import AppKit
import LovelyGlowCore

enum GlowPanelHost {
    static let cornerRadius = GlowPanelMetrics.cornerRadius

    @MainActor
    static func applyOpaqueCard(to view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}
