import ApplicationServices
import CoreGraphics
import Foundation
import LovelyGlowCore

enum AXWindowQuery {
    static func focusedWindow(for pid: pid_t) -> AXWindowSnapshot? {
        let app = AXUIElementCreateApplication(pid)
        guard let window = element(kAXFocusedWindowAttribute as CFString, of: app)
            ?? element(kAXMainWindowAttribute as CFString, of: app)
        else { return nil }
        guard let position = point(kAXPositionAttribute as CFString, of: window),
            let size = size(kAXSizeAttribute as CFString, of: window)
        else { return nil }
        return AXWindowSnapshot(
            pid: pid,
            bounds: CGRect(origin: position, size: size),
            isMinimized: bool(kAXMinimizedAttribute as CFString, of: window) ?? false,
            isFullscreen: bool("AXFullScreen" as CFString, of: window) ?? false,
            subrole: string(kAXSubroleAttribute as CFString, of: window)
        )
    }

    static func element(_ attribute: CFString, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func point(_ attribute: CFString, of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(_ attribute: CFString, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func bool(_ attribute: CFString, of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return (value as? Bool)
    }

    private static func string(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }
}
