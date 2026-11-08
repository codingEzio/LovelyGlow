import AppKit
import LovelyGlowCore

@MainActor
final class GlowRuntime {
    let store: LocalStore
    let tracker = FocusTracker()
    let overlay = OverlayController()
    private(set) var accessibilityTrusted = AccessibilityPermission.isTrusted

    init(store: LocalStore) {
        self.store = store
        applyStore()
        tracker.onChange = { [weak self] decision in
            guard let self else { return }
            self.overlay.apply(decision)
            self.tracker.overlayWindowIDs = self.overlay.windowIDs
        }
        tracker.onLiveResize = { [weak self] live in
            self?.overlay.liveResize = live
        }
        overlay.onVisualPoll = { [weak self] in
            self?.tracker.pollVisual()
        }
    }

    func start() {
        overlay.prepare()
        store.persist()
        tracker.setEnabled(store.document.enabled)
        refreshAccessibility()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled, !AccessibilityPermission.isTrusted {
            AccessibilityPermission.request()
        }
        store.update { $0.enabled = enabled }
        tracker.setEnabled(enabled)
        refreshAccessibility()
    }

    func updateDocument(_ mutate: (inout SettingsDocument) -> Void) {
        store.update(mutate)
        applyStore()
        tracker.setEnabled(store.document.enabled)
        tracker.refresh()
        refreshAccessibility()
    }

    func refreshAccessibility() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func copy(_ key: CopyKey) -> String {
        CopyCatalog.text(key, language: store.document.language)
    }

    private func applyStore() {
        let document = store.document
        tracker.includeAuxiliaryWindows = document.includeAuxiliaryWindows
        overlay.applySettings(
            style: document.style,
            scheme: document.scheme,
            animation: document.animation,
            speed: document.animationSpeed,
            arrival: document.arrival
        )
        overlay.updateAboveDock(document.glowAboveDock)
    }
}
