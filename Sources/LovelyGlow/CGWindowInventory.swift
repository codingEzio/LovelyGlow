import AppKit
import CoreGraphics
import Foundation
import LovelyGlowCore
import QuartzCore

@MainActor
enum CGWindowInventory {
    private static let cacheTTL: CFTimeInterval = 1.0 / 120
    private static var cachedAt: CFTimeInterval = 0
    private static var cachedWindows: [CGWindowSnapshot] = []
    static var currentSnapshots: [CGWindowSnapshot] { cachedWindows }

    static func snapshots(fresh: Bool = false) -> [CGWindowSnapshot] {
        let now = CACurrentMediaTime()
        if !fresh, now - cachedAt < cacheTTL, !cachedWindows.isEmpty {
            return cachedWindows
        }
        guard
            let info = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            cachedAt = now
            cachedWindows = []
            return []
        }

        let windows = info.compactMap { window -> CGWindowSnapshot? in
            guard let windowID = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { return nil }
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let alpha = CGFloat((window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
            let onscreen = (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true
            return CGWindowSnapshot(
                windowID: windowID,
                pid: pid,
                layer: layer,
                alpha: alpha,
                bounds: bounds,
                isOnscreen: onscreen,
                name: window[kCGWindowName as String] as? String
            )
        }
        cachedAt = now
        cachedWindows = windows
        return windows
    }

    static func displays() -> [DisplaySnapshot] {
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        return NSScreen.screens.compactMap { screen in
            guard
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? NSNumber
            else { return nil }
            let bounds = CGDisplayBounds(CGDirectDisplayID(displayID.uint32Value))
            let visible = WindowGeometry.cgBounds(fromCocoa: screen.visibleFrame, primaryHeight: primaryHeight)
            return DisplaySnapshot(bounds: bounds, visible: visible)
        }
    }

    static func primaryHeight() -> CGFloat {
        CGDisplayBounds(CGMainDisplayID()).height
    }

    static func chromeFrames() -> [CGRect] {
        NSScreen.screens.flatMap { screen in
            OverlayGeometry.reservedChrome(frame: screen.frame, visible: screen.visibleFrame)
        }
    }

    static func bounds(of windowID: UInt32) -> CGRect? {
        snapshots().first { window in
            window.windowID == windowID
                && window.alpha > 0.05
                && window.isOnscreen
                && window.bounds.width >= 8
                && window.bounds.height >= 8
        }?.bounds
    }
}
