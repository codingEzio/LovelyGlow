import CoreGraphics
import Foundation

/// Path parameter around a rounded rect, starting at mid-left and traveling
/// left → bottom → right → top. Shared by tests and the Metal rim shader.
public enum Perimeter {
    public static func length(hole: CGRect, radius: CGFloat) -> CGFloat {
        let r = clampedRadius(hole: hole, radius: radius)
        let innerW = max(hole.width - 2 * r, 0.001)
        let innerH = max(hole.height - 2 * r, 0.001)
        return 2 * innerW + 2 * innerH + 2 * .pi * r
    }

    public static func phase(point: CGPoint, hole: CGRect, radius: CGFloat) -> CGFloat {
        let total = length(hole: hole, radius: radius)
        guard total > 0 else { return 0 }
        return closest(point: point, hole: hole, radius: radius).arc / total
    }

    public static func closest(point: CGPoint, hole: CGRect, radius: CGFloat) -> (point: CGPoint, arc: CGFloat, distance: CGFloat) {
        let r = clampedRadius(hole: hole, radius: radius)
        let cx = hole.midX
        let cy = hole.midY
        let inner = CGPoint(
            x: max(hole.width / 2 - r, 0.0005),
            y: max(hole.height / 2 - r, 0.0005)
        )
        let p = CGPoint(x: point.x - cx, y: point.y - cy)
        let halfW = inner.x + r
        let halfH = inner.y + r

        let leftLower = inner.y
        let blArc = (.pi / 2) * r
        let bottom = 2 * inner.x
        let brArc = blArc
        let right = 2 * inner.y
        let trArc = blArc
        let top = 2 * inner.x
        let tlArc = blArc

        var bestPoint = CGPoint(x: -halfW, y: 0)
        var bestArc: CGFloat = 0
        var bestDist = CGFloat.greatestFiniteMagnitude

        func consider(candidate: CGPoint, arc: CGFloat) {
            let dx = p.x - candidate.x
            let dy = p.y - candidate.y
            let dist = dx * dx + dy * dy
            if dist < bestDist {
                bestDist = dist
                bestPoint = candidate
                bestArc = arc
            }
        }

        let leftX = -halfW
        let rightX = halfW
        let bottomY = -halfH
        let topY = halfH

        let leftY = min(max(p.y, -inner.y), inner.y)
        let leftArc = leftY <= 0 ? -leftY : leftLower + blArc + bottom + brArc + right + trArc + top + tlArc + (inner.y - leftY)
        consider(candidate: CGPoint(x: leftX, y: leftY), arc: leftArc)

        let rightY = min(max(p.y, -inner.y), inner.y)
        consider(
            candidate: CGPoint(x: rightX, y: rightY),
            arc: leftLower + blArc + bottom + brArc + (inner.y + rightY)
        )

        let bottomX = min(max(p.x, -inner.x), inner.x)
        consider(
            candidate: CGPoint(x: bottomX, y: bottomY),
            arc: leftLower + blArc + (bottomX + inner.x)
        )

        let topX = min(max(p.x, -inner.x), inner.x)
        consider(
            candidate: CGPoint(x: topX, y: topY),
            arc: leftLower + blArc + bottom + brArc + right + trArc + (inner.x - topX)
        )

        func considerArc(center: CGPoint, start: CGFloat, end: CGFloat, origin: CGFloat) {
            let dx = p.x - center.x
            let dy = p.y - center.y
            var angle = atan2(dy, dx)
            if angle < 0 { angle += 2 * .pi }
            let clamped = min(max(angle, start), end)
            let candidate = CGPoint(x: center.x + r * cos(clamped), y: center.y + r * sin(clamped))
            consider(candidate: candidate, arc: origin + (clamped - start) * r)
        }

        considerArc(center: CGPoint(x: -inner.x, y: -inner.y), start: .pi, end: .pi * 1.5, origin: leftLower)
        considerArc(
            center: CGPoint(x: inner.x, y: -inner.y),
            start: .pi * 1.5,
            end: 2 * .pi,
            origin: leftLower + blArc + bottom
        )
        considerArc(
            center: CGPoint(x: inner.x, y: inner.y),
            start: 0,
            end: .pi / 2,
            origin: leftLower + blArc + bottom + brArc + right
        )
        considerArc(
            center: CGPoint(x: -inner.x, y: inner.y),
            start: .pi / 2,
            end: .pi,
            origin: leftLower + blArc + bottom + brArc + right + trArc + top
        )

        return (
            point: CGPoint(x: bestPoint.x + cx, y: bestPoint.y + cy),
            arc: bestArc,
            distance: sqrt(bestDist)
        )
    }

    public static func clampedRadius(hole: CGRect, radius: CGFloat) -> CGFloat {
        max(min(radius, min(hole.width, hole.height) / 2), 0.5)
    }
}