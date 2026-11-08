import Foundation

/// How the rim first appears on a window.
public enum GlowArrivalID: String, CaseIterable, Sendable, Hashable {
    /// Snap onto the window with no fade or travel.
    case instant
    /// Cross-fade and ease from the previous window so the rim feels already there.
    case seamless

    public init(configValue: String) {
        self = GlowArrivalID(rawValue: configValue) ?? .instant
    }

    public var duration: TimeInterval {
        switch self {
        case .instant: return 0
        case .seamless: return 0.16
        }
    }

    /// Opacity fade when the rim appears from nothing. Travel uses `GlowTravel`.
    public static func progress(elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 1 }
        let t = min(max(elapsed / duration, 0), 1)
        let inverted = 1 - t
        return 1 - inverted * inverted * inverted
    }
}
