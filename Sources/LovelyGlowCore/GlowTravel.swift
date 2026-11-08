import CoreGraphics
import Foundation

/// Vsync-timed travel for Seamless. One critically-near spring, sampled with
/// the display-link delta, not a fixed 0.28s smoothstep.
public struct GlowTravelState: Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var w: CGFloat
    public var h: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var vw: CGFloat
    public var vh: CGFloat

    public init(
        x: CGFloat,
        y: CGFloat,
        w: CGFloat,
        h: CGFloat,
        vx: CGFloat = 0,
        vy: CGFloat = 0,
        vw: CGFloat = 0,
        vh: CGFloat = 0
    ) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.vx = vx
        self.vy = vy
        self.vw = vw
        self.vh = vh
    }

    public static func at(_ rect: CGRect) -> GlowTravelState {
        GlowTravelState(x: rect.minX, y: rect.minY, w: rect.width, h: rect.height)
    }

    public var rect: CGRect {
        CGRect(x: x, y: y, width: max(w, 1), height: max(h, 1))
    }
}

public enum GlowTravel {
    public static func retarget(_ state: GlowTravelState, to target: CGRect) -> GlowTravelState {
        var next = state
        // Preserve useful momentum, but never take the first step away from
        // the new target or carry enough velocity to overshoot a nearer target.
        func velocity(_ value: CGFloat, _ speed: CGFloat, _ goal: CGFloat) -> CGFloat {
            let distance = goal - value
            guard speed * distance > 0 else { return 0 }
            return copysign(min(abs(speed), omega * abs(distance)), distance)
        }
        next.vx = velocity(state.x, state.vx, target.minX)
        next.vy = velocity(state.y, state.vy, target.minY)
        next.vw = velocity(state.w, state.vw, target.width)
        next.vh = velocity(state.h, state.vh, target.height)
        return next
    }
    /// Critically damped, roughly 99% of travel in 140ms. Absolute settlement
    /// still depends on distance; use the thresholds below, not that estimate.
    public static let omega: CGFloat = 48
    public static let damping: CGFloat = 1
    public static let settleDistance: CGFloat = 0.3
    public static let settleVelocity: CGFloat = 18

    public static func step(state: GlowTravelState, target: CGRect, dt: TimeInterval) -> GlowTravelState {
        guard dt.isFinite, dt > 0 else { return state }
        let dt = CGFloat(dt)
        var next = state
        integrate(&next.x, &next.vx, to: target.minX, dt: dt)
        integrate(&next.y, &next.vy, to: target.minY, dt: dt)
        integrate(&next.w, &next.vw, to: target.width, dt: dt)
        integrate(&next.h, &next.vh, to: target.height, dt: dt)
        return next
    }

    public static func isSettled(_ state: GlowTravelState, target: CGRect) -> Bool {
        abs(state.x - target.minX) <= settleDistance
            && abs(state.y - target.minY) <= settleDistance
            && abs(state.w - target.width) <= settleDistance
            && abs(state.h - target.height) <= settleDistance
            && abs(state.vx) <= settleVelocity
            && abs(state.vy) <= settleVelocity
            && abs(state.vw) <= settleVelocity
            && abs(state.vh) <= settleVelocity
    }

    /// Constant Metal drawable during a hop. Origin follows the rim; size never
    /// spans the union of two windows.
    public static func drawableSize(from: CGRect, to: CGRect, pad: CGFloat) -> CGSize {
        CGSize(
            width: max(from.width, to.width) + 2 * pad,
            height: max(from.height, to.height) + 2 * pad
        )
    }

    public static func grow(_ size: CGSize, to needed: CGSize) -> CGSize {
        CGSize(width: max(size.width, needed.width), height: max(size.height, needed.height))
    }

    public static func panelFrame(drawn: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: drawn.midX - size.width / 2,
            y: drawn.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func integrate(_ value: inout CGFloat, _ velocity: inout CGFloat, to target: CGFloat, dt: CGFloat) {
        let x0 = value - target
        let v0 = velocity
        let omega = Self.omega
        let decay = CGFloat(exp(Double(-omega * dt)))
        let b = v0 + omega * x0
        let x = decay * (x0 + b * dt)
        let v = decay * (v0 - omega * b * dt)
        value = target + x
        velocity = v
    }
}
