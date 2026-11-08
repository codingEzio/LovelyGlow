import Foundation

/// Deduplicates multiple overlays reporting the same display tick.
public struct FrameGate {
    private var lastTimes: [UInt32: TimeInterval] = [:]

    public init() {}

    public mutating func consume(_ time: TimeInterval, displayID: UInt32 = 0) -> Bool {
        guard time.isFinite else { return false }
        if let lastTime = lastTimes[displayID], time <= lastTime { return false }
        lastTimes[displayID] = time
        return true
    }
}
