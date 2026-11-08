import CoreGraphics
import Foundation

public struct EdgeClearance: Equatable, Sendable {
    public var minX: CGFloat
    public var maxX: CGFloat
    public var minY: CGFloat
    public var maxY: CGFloat

    public static let flushLimit: CGFloat = 2

    public init(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }

    public static func full(pad: CGFloat) -> EdgeClearance {
        EdgeClearance(minX: pad, maxX: pad, minY: pad, maxY: pad)
    }

    public var isFlushMinX: Bool { minX < Self.flushLimit }
    public var isFlushMaxX: Bool { maxX < Self.flushLimit }
    public var isFlushMinY: Bool { minY < Self.flushLimit }
    public var isFlushMaxY: Bool { maxY < Self.flushLimit }
}

public struct OverlayLayout: Equatable, Sendable {
    public var panelFrame: CGRect
    public var windowFrameInPanel: CGRect
    public var holeFrame: CGRect
    public var rimOuter: CGRect
    public var cornerRadius: CGFloat
    public var holeRadius: CGFloat
    public var rimOuterRadius: CGFloat
    public var occluders: [CGRect]
    public var edgeClearance: EdgeClearance

    public init(
        panelFrame: CGRect,
        windowFrameInPanel: CGRect,
        holeFrame: CGRect,
        rimOuter: CGRect,
        cornerRadius: CGFloat,
        holeRadius: CGFloat,
        rimOuterRadius: CGFloat,
        occluders: [CGRect] = [],
        edgeClearance: EdgeClearance = .full(pad: 64)
    ) {
        self.panelFrame = panelFrame
        self.windowFrameInPanel = windowFrameInPanel
        self.holeFrame = holeFrame
        self.rimOuter = rimOuter
        self.cornerRadius = cornerRadius
        self.holeRadius = holeRadius
        self.rimOuterRadius = rimOuterRadius
        self.occluders = occluders
        self.edgeClearance = edgeClearance
    }
}

public enum OverlayGeometry {
    public static let clearance: CGFloat = 1.5
    public static let bloomFade: CGFloat = 3
    public static let followSlack: CGFloat = 0

    /// Full drawable for the rim, including the hole’s inner corner fillets.
    /// Four edge strips miss those corners and wrap the window as a rectangle.
    public static func rimFill(hole: CGRect, band: CGFloat) -> CGRect {
        hole.insetBy(dx: -max(band, 0), dy: -max(band, 0))
    }

    /// Signed distance to a circular rounded hole. Matches the Metal SDF.
    public static func signedDistance(point: CGPoint, hole: CGRect, radius: CGFloat) -> CGFloat {
        let p = CGPoint(x: point.x - hole.midX, y: point.y - hole.midY)
        let half = CGPoint(x: hole.width / 2, y: hole.height / 2)
        let r = min(max(radius, 0), min(half.x, half.y))
        let q = CGPoint(x: abs(p.x) - half.x + r, y: abs(p.y) - half.y + r)
        return min(max(q.x, q.y), 0) + hypot(max(q.x, 0), max(q.y, 0)) - r
    }

    public static func reservedChrome(frame: CGRect, visible: CGRect) -> [CGRect] {
        var strips: [CGRect] = []
        if frame.maxY > visible.maxY + 0.5 {
            strips.append(
                CGRect(
                    x: frame.minX,
                    y: visible.maxY,
                    width: frame.width,
                    height: frame.maxY - visible.maxY
                )
            )
        }
        if visible.minX > frame.minX + 0.5 {
            strips.append(
                CGRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: visible.minX - frame.minX,
                    height: frame.height
                )
            )
        }
        if frame.maxX > visible.maxX + 0.5 {
            strips.append(
                CGRect(
                    x: visible.maxX,
                    y: frame.minY,
                    width: frame.maxX - visible.maxX,
                    height: frame.height
                )
            )
        }
        if visible.minY > frame.minY + 0.5 {
            strips.append(
                CGRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: frame.width,
                    height: visible.minY - frame.minY
                )
            )
        }
        return strips
    }

    public static func pad(for style: GlowStyle) -> CGFloat {
        max(style.spread, max(style.lineWidth, 2)) + Self.clearance + Self.bloomFade
    }

    public static func slackFrame(windowCocoa: CGRect, style: GlowStyle) -> CGRect {
        windowCocoa.insetBy(dx: -(pad(for: style) + followSlack), dy: -(pad(for: style) + followSlack))
    }

    public static func lerp(_ from: CGRect, _ to: CGRect, t: CGFloat) -> CGRect {
        let t = min(max(t, 0), 1)
        return CGRect(
            x: from.minX + (to.minX - from.minX) * t,
            y: from.minY + (to.minY - from.minY) * t,
            width: from.width + (to.width - from.width) * t,
            height: from.height + (to.height - from.height) * t
        )
    }

    public static func canFollow(windowCocoa: CGRect, panelFrame: CGRect, style: GlowStyle) -> Bool {
        let needed = windowCocoa.insetBy(dx: -pad(for: style), dy: -pad(for: style))
        return panelFrame.insetBy(dx: 12, dy: 12).contains(needed)
    }

    public static func edgeClearance(
        windowCocoa window: CGRect,
        chrome: [CGRect],
        pad: CGFloat,
        screens: [CGRect] = []
    ) -> EdgeClearance {
        var minX = pad
        var maxX = pad
        var minY = pad
        var maxY = pad

        for strip in chrome {
            if strip.minY < window.maxY, strip.maxY > window.minY {
                if strip.maxX <= window.minX + 1 || (strip.minX < window.minX && strip.maxX > window.minX - pad * 2) {
                    minX = min(minX, max(0, window.minX - strip.maxX))
                }
                if strip.minX >= window.maxX - 1 || (strip.maxX > window.maxX && strip.minX < window.maxX + pad * 2) {
                    maxX = min(maxX, max(0, strip.minX - window.maxX))
                }
            }
            if strip.minX < window.maxX, strip.maxX > window.minX {
                if strip.maxY <= window.minY + 1 || (strip.minY < window.minY && strip.maxY > window.minY - pad * 2) {
                    minY = min(minY, max(0, window.minY - strip.maxY))
                }
                if strip.minY >= window.maxY - 1 || (strip.maxY > window.maxY && strip.minY < window.maxY + pad * 2) {
                    maxY = min(maxY, max(0, strip.minY - window.maxY))
                }
            }
        }

        for screen in screens where screen.intersects(window.insetBy(dx: -1, dy: -1)) {
            minX = min(minX, max(0, window.minX - screen.minX))
            maxX = min(maxX, max(0, screen.maxX - window.maxX))
            minY = min(minY, max(0, window.minY - screen.minY))
            maxY = min(maxY, max(0, screen.maxY - window.maxY))
        }

        return EdgeClearance(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    public static func outerExpand(air: CGFloat, requested: CGFloat) -> CGFloat {
        if air < EdgeClearance.flushLimit { return 0 }
        let needed = requested + Self.bloomFade
        if air >= needed { return requested }
        return max(air - Self.clearance, 1)
    }

    public static func holeShift(
        air: CGFloat,
        base: CGFloat,
        inner: CGFloat,
        flushInset: CGFloat
    ) -> CGFloat {
        if air < EdgeClearance.flushLimit {
            return -max(inner, flushInset)
        }
        return min(base, max(air - inner, 0.5))
    }

    public static func flushInset(for style: GlowStyle) -> CGFloat {
        max(style.spread * 0.7, 10)
    }

    public static func needsEdgeRelayout(
        windowCocoa: CGRect,
        previous: CGRect?,
        chrome: [CGRect],
        screens: [CGRect],
        pad: CGFloat
    ) -> Bool {
        guard let previous, previous.size == windowCocoa.size else { return true }
        return edgeClearance(windowCocoa: windowCocoa, chrome: chrome, pad: pad, screens: screens)
            != edgeClearance(windowCocoa: previous, chrome: chrome, pad: pad, screens: screens)
    }

    public static func layout(
        windowCocoa: CGRect,
        style: GlowStyle,
        primaryHeight: CGFloat
    ) -> OverlayLayout {
        aligned(
            windowCocoa: windowCocoa,
            panelFrame: windowCocoa.insetBy(dx: -pad(for: style), dy: -pad(for: style)),
            style: style
        )
    }

    public static func aligned(
        windowCocoa: CGRect,
        panelFrame: CGRect,
        style: GlowStyle,
        occludersCocoa: [CGRect] = [],
        screensCocoa: [CGRect] = []
    ) -> OverlayLayout {
        let pad = pad(for: style)
        let rim = max(style.lineWidth, 2)
        let windowInPanel = CGRect(
            x: windowCocoa.minX - panelFrame.minX,
            y: windowCocoa.minY - panelFrame.minY,
            width: windowCocoa.width,
            height: windowCocoa.height
        )
        let radius = style.strokeRadius(forWindowBounds: windowCocoa)
        let panelLocal = CGRect(origin: .zero, size: panelFrame.size)
        let occluders = occludersCocoa.map { rect in
            CGRect(
                x: rect.minX - panelFrame.minX,
                y: rect.minY - panelFrame.minY,
                width: rect.width,
                height: rect.height
            )
        }.filter { $0.intersects(panelLocal) }
        let clearance = edgeClearance(
            windowCocoa: windowCocoa,
            chrome: occludersCocoa,
            pad: pad,
            screens: screensCocoa
        )
        let inner = max(style.lineWidth, 2) / 2 + 0.5
        let flushInset = flushInset(for: style)
        let shiftMinX = holeShift(air: clearance.minX, base: Self.clearance, inner: inner, flushInset: flushInset)
        let shiftMaxX = holeShift(air: clearance.maxX, base: Self.clearance, inner: inner, flushInset: flushInset)
        let shiftMinY = holeShift(air: clearance.minY, base: Self.clearance, inner: inner, flushInset: flushInset)
        let shiftMaxY = holeShift(air: clearance.maxY, base: Self.clearance, inner: inner, flushInset: flushInset)
        let hole = CGRect(
            x: windowInPanel.minX - shiftMinX,
            y: windowInPanel.minY - shiftMinY,
            width: windowInPanel.width + shiftMinX + shiftMaxX,
            height: windowInPanel.height + shiftMinY + shiftMaxY
        )
        let expandMinX = outerExpand(air: clearance.minX, requested: rim)
        let expandMaxX = outerExpand(air: clearance.maxX, requested: rim)
        let expandMinY = outerExpand(air: clearance.minY, requested: rim)
        let expandMaxY = outerExpand(air: clearance.maxY, requested: rim)
        let rimOuter = CGRect(
            x: hole.minX - expandMinX,
            y: hole.minY - expandMinY,
            width: hole.width + expandMinX + expandMaxX,
            height: hole.height + expandMinY + expandMaxY
        )
        let outerGrow = max(expandMinX, expandMaxX, expandMinY, expandMaxY)
        let expansion = (
            (windowInPanel.minX - hole.minX)
                + (hole.maxX - windowInPanel.maxX)
                + (windowInPanel.minY - hole.minY)
                + (hole.maxY - windowInPanel.maxY)
        ) / 4
        let holeRadius = WindowChrome.concentricRadius(radius, expansion: expansion)
        return OverlayLayout(
            panelFrame: panelFrame,
            windowFrameInPanel: windowInPanel,
            holeFrame: hole,
            rimOuter: rimOuter,
            cornerRadius: radius,
            holeRadius: holeRadius,
            rimOuterRadius: holeRadius + outerGrow,
            occluders: occluders,
            edgeClearance: clearance
        )
    }

    public static func layout(
        windowCG: CGRect,
        style: GlowStyle,
        primaryHeight: CGFloat
    ) -> OverlayLayout {
        layout(
            windowCocoa: WindowGeometry.cocoaFrame(fromCG: windowCG, primaryHeight: primaryHeight),
            style: style,
            primaryHeight: primaryHeight
        )
    }

    public static func strokePath(
        hole: CGRect,
        holeRadius: CGFloat,
        lineWidth: CGFloat
    ) -> CGPath {
        let width = max(lineWidth, 1)
        let center = hole.insetBy(dx: -width / 2, dy: -width / 2)
        let radius = holeRadius + width / 2
        return CGPath(
            roundedRect: center,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }

    public static func filamentPath(
        hole: CGRect,
        holeRadius: CGFloat,
        lineWidth: CGFloat,
        clearance: EdgeClearance
    ) -> CGPath {
        let path = CGMutablePath()
        let width = max(lineWidth, 1)
        let rim = hole.insetBy(dx: -width / 2, dy: -width / 2)
        let radius = max(min(holeRadius + width / 2, min(rim.width, rim.height) / 2), 0.5)
        let bottomLeft = CGPoint(x: rim.minX + radius, y: rim.minY + radius)
        let bottomRight = CGPoint(x: rim.maxX - radius, y: rim.minY + radius)
        let topRight = CGPoint(x: rim.maxX - radius, y: rim.maxY - radius)
        let topLeft = CGPoint(x: rim.minX + radius, y: rim.maxY - radius)

        func addCorner(center: CGPoint, start: CGFloat, end: CGFloat) {
            let startPoint = CGPoint(
                x: center.x + radius * Foundation.cos(start),
                y: center.y + radius * Foundation.sin(start)
            )
            path.move(to: startPoint)
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        }

        addCorner(center: bottomLeft, start: .pi, end: .pi * 1.5)
        addCorner(center: bottomRight, start: .pi * 1.5, end: 0)
        addCorner(center: topRight, start: 0, end: .pi / 2)
        addCorner(center: topLeft, start: .pi / 2, end: .pi)

        path.move(to: CGPoint(x: rim.minX, y: rim.minY + radius))
        path.addLine(to: CGPoint(x: rim.minX, y: rim.maxY - radius))
        path.move(to: CGPoint(x: rim.maxX, y: rim.maxY - radius))
        path.addLine(to: CGPoint(x: rim.maxX, y: rim.minY + radius))
        path.move(to: CGPoint(x: rim.minX + radius, y: rim.minY))
        path.addLine(to: CGPoint(x: rim.maxX - radius, y: rim.minY))
        path.move(to: CGPoint(x: rim.maxX - radius, y: rim.maxY))
        path.addLine(to: CGPoint(x: rim.minX + radius, y: rim.maxY))
        _ = clearance

        return path
    }

    public static func airMask(
        bounds: CGRect,
        hole: CGRect,
        holeRadius: CGFloat,
        occluders: [CGRect]
    ) -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRoundedRect(in: hole, cornerWidth: holeRadius, cornerHeight: holeRadius)
        for occluder in occluders where occluder.intersects(bounds) {
            path.addRect(occluder)
        }
        return path
    }

    public static func ringPath(
        hole: CGRect,
        outer: CGRect,
        holeRadius: CGFloat,
        outerRadius: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: outer, cornerWidth: outerRadius, cornerHeight: outerRadius)
        path.addRoundedRect(in: hole, cornerWidth: holeRadius, cornerHeight: holeRadius)
        return path
    }
}
