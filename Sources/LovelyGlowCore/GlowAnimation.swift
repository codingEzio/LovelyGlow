import CoreGraphics
import Foundation

/// Built-in motion ids. Add a case, a plugin, and a copy key to ship a new loop.
public enum GlowAnimationID: String, CaseIterable, Sendable {
    case still
    case orbit
    case breathe
    case comet
    case orbitBreathe

    public init(configValue: String) {
        self = GlowAnimationID(rawValue: configValue) ?? .orbitBreathe
    }

    public var loops: Bool {
        GlowAnimationRegistry.plugin(id: self).loops
    }
}

public struct GlowAnimationState: Equatable, Sendable {
    public var travel: CGFloat
    public var breathe: CGFloat
    public var comet: CGFloat
    public var sheen: CGFloat

    public init(travel: CGFloat, breathe: CGFloat, comet: CGFloat, sheen: CGFloat) {
        self.travel = Self.wrap(travel)
        self.breathe = min(max(breathe, 0.2), 2)
        self.comet = min(max(comet, 0), 1)
        self.sheen = min(max(sheen, 0), 2)
    }

    public static let still = GlowAnimationState(travel: 0, breathe: 1, comet: 0, sheen: 1)

    public static func wrap(_ value: CGFloat) -> CGFloat {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }
}

public protocol GlowAnimationPlugin: Sendable {
    var id: GlowAnimationID { get }
    var loops: Bool { get }
    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState
}

public enum GlowAnimationRegistry {
    public static let plugins: [any GlowAnimationPlugin] = [
        StillAnimation(),
        OrbitAnimation(),
        BreatheAnimation(),
        CometAnimation(),
        OrbitBreatheAnimation(),
    ]

    public static func plugin(id: GlowAnimationID) -> any GlowAnimationPlugin {
        plugins.first { $0.id == id } ?? StillAnimation()
    }

    public static func evaluate(
        id: GlowAnimationID,
        time: TimeInterval,
        speed: CGFloat,
        reducedMotion: Bool
    ) -> GlowAnimationState {
        _ = reducedMotion
        return plugin(id: id).evaluate(time: time, speed: max(speed, 0.05))
    }
}

public enum GlowMotion {
    public static let defaultSpeed: CGFloat = 1
    public static let minimumSpeed: CGFloat = 0.05
    public static let maximumSpeed: CGFloat = 12
    public static let orbitPeriod: TimeInterval = 6
    public static let breathePeriod: TimeInterval = 5

    public static func clampSpeed(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumSpeed), maximumSpeed)
    }

    /// A logarithmic control gives the everyday 0.5–2× range usable travel
    /// while preserving both existing extreme settings.
    public static func sliderPosition(for speed: CGFloat) -> Double {
        let minimum = Double(minimumSpeed)
        let maximum = Double(maximumSpeed)
        return log(Double(clampSpeed(speed)) / minimum) / log(maximum / minimum)
    }

    public static func speed(atSliderPosition position: Double) -> CGFloat {
        if position <= 0 { return minimumSpeed }
        if position >= 1 { return maximumSpeed }
        let minimum = Double(minimumSpeed)
        let maximum = Double(maximumSpeed)
        return CGFloat(minimum * pow(maximum / minimum, position))
    }

    public static func cycle(_ time: TimeInterval, period: TimeInterval, speed: CGFloat) -> CGFloat {
        let scaled = period / Double(max(speed, 0.05))
        guard scaled > 0 else { return 0 }
        let phase = time.truncatingRemainder(dividingBy: scaled) / scaled
        return CGFloat(phase < 0 ? phase + 1 : phase)
    }
}

struct StillAnimation: GlowAnimationPlugin {
    let id = GlowAnimationID.still
    let loops = false

    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState {
        _ = time
        _ = speed
        return .still
    }
}

struct OrbitAnimation: GlowAnimationPlugin {
    let id = GlowAnimationID.orbit
    let loops = true

    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState {
        GlowAnimationState(
            travel: GlowMotion.cycle(time, period: GlowMotion.orbitPeriod, speed: speed),
            breathe: 1,
            comet: 0.58,
            sheen: 1
        )
    }
}

struct BreatheAnimation: GlowAnimationPlugin {
    let id = GlowAnimationID.breathe
    let loops = true

    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState {
        let phase = GlowMotion.cycle(time, period: GlowMotion.breathePeriod, speed: speed)
        let wave = 0.5 - 0.5 * cos(2 * CGFloat.pi * phase)
        return GlowAnimationState(
            travel: 0,
            breathe: 0.78 + 0.28 * wave,
            comet: 0,
            sheen: 0.72 + 0.28 * wave
        )
    }
}

struct CometAnimation: GlowAnimationPlugin {
    let id = GlowAnimationID.comet
    let loops = true

    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState {
        GlowAnimationState(
            travel: GlowMotion.cycle(time, period: GlowMotion.orbitPeriod, speed: speed),
            breathe: 1,
            comet: 0.84,
            sheen: 1.15
        )
    }
}

struct OrbitBreatheAnimation: GlowAnimationPlugin {
    let id = GlowAnimationID.orbitBreathe
    let loops = true

    func evaluate(time: TimeInterval, speed: CGFloat) -> GlowAnimationState {
        let phase = GlowMotion.cycle(time, period: GlowMotion.breathePeriod, speed: speed)
        let wave = 0.5 - 0.5 * cos(2 * CGFloat.pi * phase)
        return GlowAnimationState(
            travel: GlowMotion.cycle(time, period: GlowMotion.orbitPeriod, speed: speed),
            breathe: 0.84 + 0.22 * wave,
            comet: 0.52,
            sheen: 0.9 + 0.2 * wave
        )
    }
}
