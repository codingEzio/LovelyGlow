import CoreGraphics
import Testing
@testable import LovelyGlowCore

struct OverlayGeometryTests {
    @Test func holeStaysOutsideTheWindow() {
        let cocoa = CGRect(x: 200, y: 140, width: 800, height: 500)
        let style = GlowStyle.default
        let layout = OverlayGeometry.layout(windowCocoa: cocoa, style: style, primaryHeight: 982)
        let pad = OverlayGeometry.pad(for: style)
        #expect(layout.panelFrame == cocoa.insetBy(dx: -pad, dy: -pad))
        #expect(layout.windowFrameInPanel.origin == CGPoint(x: pad, y: pad))
        #expect(layout.windowFrameInPanel.size == cocoa.size)
        #expect(layout.holeFrame.contains(layout.windowFrameInPanel.insetBy(dx: 0.01, dy: 0.01)))
        #expect(layout.holeFrame.minX < layout.windowFrameInPanel.minX)
        #expect(layout.rimOuter.minX < layout.holeFrame.minX)
        let drawn = WindowChrome.radius(forWindowBounds: cocoa)
        #expect(layout.cornerRadius == drawn)
        #expect(layout.holeRadius == WindowChrome.concentricRadius(drawn, expansion: OverlayGeometry.clearance))
        #expect(drawn > WindowChrome.standardRadius)
    }

    @Test func cornerRadiusDoesNotExceedHalfTheShortSide() {
        var style = GlowStyle.default
        style.cornerRadius = 40
        let layout = OverlayGeometry.layout(
            windowCocoa: CGRect(x: 0, y: 0, width: 60, height: 30),
            style: style,
            primaryHeight: 982
        )
        #expect(layout.cornerRadius == 15)
        #expect(layout.holeRadius == 15 + OverlayGeometry.clearance)
    }

    @Test func windowChromeMatchesMacOSTitledCorners() {
        #expect(WindowChrome.standardRadius == 16)
        #expect(WindowChrome.visualRadius(16) == 16 * WindowChrome.continuousBoost)
        #expect(WindowChrome.visualRadius(16) > 16)
        #expect(
            WindowChrome.radius(forWindowBounds: CGRect(x: 0, y: 0, width: 800, height: 500))
                == WindowChrome.visualRadius(16)
        )
        #expect(WindowChrome.radius(forWindowBounds: CGRect(x: 0, y: 0, width: 20, height: 20)) == 10)
        #expect(WindowChrome.resolvedRadius(values: [16, 16, 16, 16]) == 16)
        #expect(WindowChrome.resolvedRadius(values: [8, 10, 8, 10]) == 9)
        #expect(WindowChrome.resolvedRadius(values: []) == WindowChrome.standardRadius)
        #expect(WindowChrome.resolvedRadius(values: [0, 0, 0, 0]) == WindowChrome.standardRadius)
        #expect(WindowChrome.concentricRadius(16, expansion: 1.5) == 17.5)
        #expect(WindowChrome.concentricRadius(16, expansion: -10) == 6)
        var styled = GlowStyle.default
        styled.cornerRadius = 28
        #expect(
            styled.strokeRadius(forWindowBounds: CGRect(x: 0, y: 0, width: 800, height: 500))
                == WindowChrome.visualRadius(28)
        )
    }

    @Test func measuredCornerRadiusIsCalibratedExactlyOnceAtTheLayoutBoundary() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 500)
        let style = GlowStyle.default.withReportedCornerRadius(16)
        let layout = OverlayGeometry.layout(windowCocoa: bounds, style: style, primaryHeight: 982)

        #expect(style.cornerRadius == 16)
        #expect(layout.cornerRadius == 16 * WindowChrome.continuousBoost)
        #expect(
            layout.holeRadius
                == WindowChrome.concentricRadius(layout.cornerRadius, expansion: OverlayGeometry.clearance)
        )
    }

    @Test func rimFillCoversTheInnerCornerThatFourStripsMiss() {
        let hole = CGRect(x: 40, y: 30, width: 200, height: 120)
        let band: CGFloat = 18
        let fillet = CGPoint(x: hole.minX + 4, y: hole.maxY - 4)
        let top = CGRect(x: hole.minX - band, y: hole.maxY, width: hole.width + 2 * band, height: band)
        let bottom = CGRect(x: hole.minX - band, y: hole.minY - band, width: hole.width + 2 * band, height: band)
        let left = CGRect(x: hole.minX - band, y: hole.minY, width: band, height: hole.height)
        let right = CGRect(x: hole.maxX, y: hole.minY, width: band, height: hole.height)
        #expect(!top.contains(fillet))
        #expect(!bottom.contains(fillet))
        #expect(!left.contains(fillet))
        #expect(!right.contains(fillet))
        #expect(OverlayGeometry.rimFill(hole: hole, band: band).contains(fillet))
    }

    @Test func continuousHoleCutsTheBoundingBoxCorner() {
        let hole = CGRect(x: 0, y: 0, width: 400, height: 300)
        let radius = WindowChrome.visualRadius(16)
        let corner = CGPoint(x: hole.minX, y: hole.minY)
        let midLeft = CGPoint(x: hole.minX, y: hole.midY)
        #expect(OverlayGeometry.signedDistance(point: corner, hole: hole, radius: radius) > 4)
        #expect(abs(OverlayGeometry.signedDistance(point: midLeft, hole: hole, radius: radius)) < 0.6)
    }

    @Test func roundedHoleFollowsACircularArc() {
        let hole = CGRect(x: 0, y: 0, width: 400, height: 300)
        let radius = WindowChrome.visualRadius(16)
        let center = CGPoint(x: hole.minX + radius, y: hole.minY + radius)
        let point = CGPoint(
            x: center.x - radius * CGFloat(2).squareRoot() / 2,
            y: center.y - radius * CGFloat(2).squareRoot() / 2
        )
        #expect(abs(OverlayGeometry.signedDistance(point: point, hole: hole, radius: radius)) < 0.6)
    }

    @Test func tightPanelTracksByRebasingInsteadOfAHugeSlack() {
        let window = CGRect(x: 300, y: 200, width: 700, height: 480)
        let style = GlowStyle.default
        let slack = OverlayGeometry.slackFrame(windowCocoa: window, style: style)
        let pad = OverlayGeometry.pad(for: style)
        #expect(slack == window.insetBy(dx: -pad, dy: -pad))
        #expect(
            !OverlayGeometry.canFollow(
                windowCocoa: window.offsetBy(dx: 40, dy: -20),
                panelFrame: slack,
                style: style
            )
        )
    }

    @Test func padFollowsSpreadInsteadOfAHiddenFloor() {
        var style = GlowStyle.default
        style.spread = 13
        style.lineWidth = 10
        let pad = OverlayGeometry.pad(for: style)
        #expect(pad == 13 + OverlayGeometry.clearance + OverlayGeometry.bloomFade)
        #expect(pad < 20)
    }

    @Test func alignedHoleFollowsTheWindowWhenThePanelIsClamped() {
        let window = CGRect(x: 66, y: 561, width: 991, height: 561)
        let desired = OverlayGeometry.layout(
            windowCocoa: window,
            style: .default,
            primaryHeight: 1152
        )
        var clamped = desired.panelFrame
        clamped.origin.y -= 30
        let aligned = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: clamped,
            style: .default
        )
        #expect(aligned.panelFrame == clamped)
        #expect(aligned.windowFrameInPanel.origin.x == window.minX - clamped.minX)
        #expect(aligned.windowFrameInPanel.origin.y == window.minY - clamped.minY)
        #expect(aligned.windowFrameInPanel.size == window.size)
        #expect(aligned.holeFrame.minY < aligned.windowFrameInPanel.minY)
        #expect(aligned.holeFrame.maxY > aligned.windowFrameInPanel.maxY)
    }

    @Test func strokePathSitsOnTheOutsideOfTheHole() {
        let hole = CGRect(x: 40, y: 30, width: 200, height: 120)
        let path = OverlayGeometry.strokePath(hole: hole, holeRadius: 16, lineWidth: 4)
        let box = path.boundingBox
        #expect(abs(box.minX - (hole.minX - 2)) < 0.01)
        #expect(abs(box.maxX - (hole.maxX + 2)) < 0.01)
        #expect(abs(box.minY - (hole.minY - 2)) < 0.01)
        #expect(abs(box.maxY - (hole.maxY + 2)) < 0.01)
    }

    @Test func airMaskKeepsTheWindowAndNeighborsClear() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 160)
        let hole = CGRect(x: 20, y: 20, width: 120, height: 90)
        let neighbor = CGRect(x: 150, y: 10, width: 80, height: 140)
        let path = OverlayGeometry.airMask(
            bounds: bounds,
            hole: hole,
            holeRadius: 12,
            occluders: [neighbor]
        )
        #expect(path.contains(CGPoint(x: 10, y: 80), using: .evenOdd))
        #expect(!path.contains(CGPoint(x: hole.midX, y: hole.midY), using: .evenOdd))
        #expect(!path.contains(CGPoint(x: neighbor.midX, y: neighbor.midY), using: .evenOdd))
    }

    @Test func alignedOccludersAreLocalToThePanel() {
        let window = CGRect(x: 100, y: 80, width: 400, height: 300)
        let neighbor = CGRect(x: 500, y: 60, width: 200, height: 340)
        let layout = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: window.insetBy(dx: -20, dy: -20),
            style: .default,
            occludersCocoa: [neighbor]
        )
        #expect(layout.occluders.count == 1)
        #expect(abs((layout.occluders.first?.minX ?? -1) - 420) < 0.01)
    }

    @Test func reservedChromeFindsALeftDockAndMenuBar() {
        let frame = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let visible = CGRect(x: 80, y: 0, width: 1968, height: 1122)
        let chrome = OverlayGeometry.reservedChrome(frame: frame, visible: visible)
        #expect(chrome.count == 2)
        #expect(chrome.contains { abs($0.minX - 0) < 0.01 && abs($0.width - 80) < 0.01 })
        #expect(chrome.contains { abs($0.minY - 1122) < 0.01 && abs($0.height - 30) < 0.01 })
    }

    @Test func nearLeftDockKeepsCompressedLeftAir() {
        let frame = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let visible = CGRect(x: 80, y: 0, width: 1968, height: 1122)
        let chrome = OverlayGeometry.reservedChrome(frame: frame, visible: visible)
        let window = CGRect(x: 84, y: 200, width: 900, height: 600)
        let pad = OverlayGeometry.pad(for: .default)
        let clearance = OverlayGeometry.edgeClearance(
            windowCocoa: window,
            chrome: chrome,
            pad: pad,
            screens: [frame]
        )
        #expect(abs(clearance.minX - 4) < 0.01)
        #expect(!clearance.isFlushMinX)
        #expect(!clearance.isFlushMaxX)
        let requested: CGFloat = 2.8
        let expand = OverlayGeometry.outerExpand(air: clearance.minX, requested: requested)
        #expect(expand > 0)
        #expect(expand < requested)
        let layout = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: window.insetBy(dx: -pad, dy: -pad),
            style: .default,
            occludersCocoa: chrome,
            screensCocoa: [frame]
        )
        #expect(layout.edgeClearance.minX == clearance.minX)
        #expect(layout.rimOuter.minX > layout.holeFrame.minX - requested)
        #expect(layout.rimOuter.minX < layout.holeFrame.minX)
    }

    @Test func flushLeftDockPinsTheLeftFilamentOnTheWindow() {
        let frame = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let visible = CGRect(x: 80, y: 0, width: 1968, height: 1122)
        let chrome = OverlayGeometry.reservedChrome(frame: frame, visible: visible)
        let window = CGRect(x: 80, y: 200, width: 900, height: 600)
        let pad = OverlayGeometry.pad(for: .default)
        let clearance = OverlayGeometry.edgeClearance(
            windowCocoa: window,
            chrome: chrome,
            pad: pad,
            screens: [frame]
        )
        #expect(clearance.isFlushMinX)
        #expect(!clearance.isFlushMaxX)
        #expect(OverlayGeometry.outerExpand(air: clearance.minX, requested: 2.8) == 0)

        let layout = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: window.insetBy(dx: -pad, dy: -pad),
            style: .default,
            occludersCocoa: chrome,
            screensCocoa: [frame]
        )
        let inset = OverlayGeometry.flushInset(for: .default)
        #expect(layout.holeFrame.minX > layout.windowFrameInPanel.minX + 8)
        #expect(abs(layout.holeFrame.minX - (layout.windowFrameInPanel.minX + inset)) < 0.01)
        #expect(abs(layout.rimOuter.minX - layout.holeFrame.minX) < 0.01)
        #expect(layout.rimOuter.maxX > layout.holeFrame.maxX)
        let rim = layout.holeFrame.insetBy(dx: -1.4, dy: -1.4)
        let path = OverlayGeometry.filamentPath(
            hole: layout.holeFrame,
            holeRadius: layout.holeRadius,
            lineWidth: 2.8,
            clearance: clearance
        )
        let lines = lineSegments(in: path)
        #expect(hasVerticalMid(in: lines, x: rim.minX, midY: layout.holeFrame.midY))
        #expect(hasVerticalMid(in: lines, x: rim.maxX, midY: layout.holeFrame.midY))
    }

    @Test func maximizedWindowKeepsAVisibleInnerCollar() {
        let frame = CGRect(x: 316, y: -967, width: 1496, height: 967)
        let visible = CGRect(x: 316, y: -967, width: 1496, height: 939.5)
        let chrome = OverlayGeometry.reservedChrome(frame: frame, visible: visible)
        let window = visible
        let pad = OverlayGeometry.pad(for: .default)
        let layout = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: window.insetBy(dx: -pad, dy: -pad),
            style: .default,
            occludersCocoa: chrome,
            screensCocoa: [frame]
        )
        let inset = OverlayGeometry.flushInset(for: .default)
        let visual = WindowChrome.radius(forWindowBounds: window)
        #expect(layout.edgeClearance.isFlushMinX)
        #expect(layout.edgeClearance.isFlushMaxX)
        #expect(layout.edgeClearance.isFlushMinY)
        #expect(layout.edgeClearance.isFlushMaxY)
        #expect(layout.holeFrame.minX >= layout.windowFrameInPanel.minX + 10)
        #expect(abs(layout.holeFrame.minX - (layout.windowFrameInPanel.minX + inset)) < 0.01)
        #expect(abs(layout.holeFrame.maxX - (layout.windowFrameInPanel.maxX - inset)) < 0.01)
        #expect(abs(layout.rimOuter.minX - layout.holeFrame.minX) < 0.01)
        #expect(abs(layout.rimOuter.maxX - layout.holeFrame.maxX) < 0.01)
        #expect(layout.holeRadius == WindowChrome.concentricRadius(visual, expansion: -inset))
        #expect(layout.holeRadius < visual)
    }

    @Test func topRightQuarterKeepsTheOuterFilament() {
        let frame = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let visible = CGRect(x: 80, y: 0, width: 1968, height: 1122)
        let chrome = OverlayGeometry.reservedChrome(frame: frame, visible: visible)
        let window = CGRect(x: 1064, y: 561, width: 984, height: 561)
        let pad = OverlayGeometry.pad(for: .default)
        let layout = OverlayGeometry.aligned(
            windowCocoa: window,
            panelFrame: window.insetBy(dx: -pad, dy: -pad),
            style: .default,
            occludersCocoa: chrome,
            screensCocoa: [frame]
        )
        #expect(layout.edgeClearance.isFlushMaxX)
        #expect(layout.edgeClearance.isFlushMaxY)
        #expect(!layout.edgeClearance.isFlushMinX)
        #expect(layout.holeFrame.maxX < layout.windowFrameInPanel.maxX)
        #expect(layout.holeFrame.maxY < layout.windowFrameInPanel.maxY)
        let rim = layout.holeFrame.insetBy(dx: -1.4, dy: -1.4)
        let path = OverlayGeometry.filamentPath(
            hole: layout.holeFrame,
            holeRadius: layout.holeRadius,
            lineWidth: 2.8,
            clearance: layout.edgeClearance
        )
        let lines = lineSegments(in: path)
        #expect(hasVerticalMid(in: lines, x: rim.maxX, midY: layout.holeFrame.midY))
        #expect(hasHorizontalMid(in: lines, y: rim.maxY, midX: layout.holeFrame.midX))
        #expect(hasVerticalMid(in: lines, x: rim.minX, midY: layout.holeFrame.midY))
    }

    @Test func roomyTranslationDoesNotNeedARelayout() {
        let frame = CGRect(x: 0, y: 0, width: 2048, height: 1152)
        let window = CGRect(x: 400, y: 200, width: 800, height: 500)
        let moved = window.offsetBy(dx: 40, dy: -20)
        let pad = OverlayGeometry.pad(for: .default)
        #expect(
            !OverlayGeometry.needsEdgeRelayout(
                windowCocoa: moved,
                previous: window,
                chrome: [],
                screens: [frame],
                pad: pad
            )
        )
        #expect(
            OverlayGeometry.needsEdgeRelayout(
                windowCocoa: CGRect(x: 80, y: 200, width: 800, height: 500),
                previous: window,
                chrome: OverlayGeometry.reservedChrome(
                    frame: frame,
                    visible: CGRect(x: 80, y: 0, width: 1968, height: 1122)
                ),
                screens: [frame],
                pad: pad
            )
        )
    }

    private func hasVerticalMid(in lines: [LineSegment], x: CGFloat, midY: CGFloat) -> Bool {
        lines.contains { segment in
            abs(segment.start.x - x) < 0.4
                && abs(segment.end.x - x) < 0.4
                && min(segment.start.y, segment.end.y) < midY
                && max(segment.start.y, segment.end.y) > midY
        }
    }

    private func hasHorizontalMid(in lines: [LineSegment], y: CGFloat, midX: CGFloat) -> Bool {
        lines.contains { segment in
            abs(segment.start.y - y) < 0.4
                && abs(segment.end.y - y) < 0.4
                && min(segment.start.x, segment.end.x) < midX
                && max(segment.start.x, segment.end.x) > midX
        }
    }

    private struct LineSegment {
        var start: CGPoint
        var end: CGPoint
    }

    private func lineSegments(in path: CGPath) -> [LineSegment] {
        var segments: [LineSegment] = []
        var current = CGPoint.zero
        var hasCurrent = false
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                current = points[0]
                hasCurrent = true
            case .addLineToPoint:
                if hasCurrent {
                    segments.append(LineSegment(start: current, end: points[0]))
                }
                current = points[0]
                hasCurrent = true
            case .addQuadCurveToPoint:
                current = points[1]
                hasCurrent = true
            case .addCurveToPoint:
                current = points[2]
                hasCurrent = true
            case .closeSubpath:
                hasCurrent = false
            @unknown default:
                break
            }
        }
        return segments
    }
}
