import CoreGraphics
import Foundation

public enum WindowGeometry {
    public static func cocoaFrame(fromCG bounds: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: bounds.origin.x,
            y: primaryHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }

    public static func cgBounds(fromCocoa frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: primaryHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    public static func cgPoint(fromCocoa point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Choose the display containing most of the window, regardless of layout.
    /// A window wholly outside the desktop has no owning display.
    public static func displayIndex(for window: CGRect, in displays: [CGRect]) -> Int? {
        var selected: Int?
        var largest: CGFloat = 0
        for (index, display) in displays.enumerated() {
            let intersection = display.intersection(window)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            if area > largest {
                selected = index
                largest = area
            }
        }
        return selected
    }

    /// Status-bar windows use a negative `windowNumber`. `UInt32(Int)` traps on that.
    public static func cgWindowID(fromWindowNumber number: Int) -> UInt32? {
        UInt32(exactly: number).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Metal fragment `[[position]]` is top-left. AppKit views are bottom-left.
    public static func metalTopLeft(rect: CGRect, viewHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: viewHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

extension CGRect {
    public var area: CGFloat { max(0, width) * max(0, height) }
}
