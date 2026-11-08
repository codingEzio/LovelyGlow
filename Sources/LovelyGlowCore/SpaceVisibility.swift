import Foundation

/// WindowServer evidence, independent of transient window bounds during a swipe.
public struct SpaceObservation: Equatable, Sendable {
    public var spaceID: UInt64
    public var spaceType: Int32
    public var windowSpaceTypes: [Int32]
    public var windowOnCurrentSpace: Bool

    public init(spaceID: UInt64, spaceType: Int32, windowSpaceTypes: [Int32] = [], windowOnCurrentSpace: Bool = true) {
        self.spaceID = spaceID
        self.spaceType = spaceType
        self.windowSpaceTypes = windowSpaceTypes
        self.windowOnCurrentSpace = windowOnCurrentSpace
    }
}

public struct SpaceVisibility {
    public private(set) var needsConfirmation = false
    private var lastSpaceID: UInt64?
    private var wasBlocked = false
    private var pending: SpaceObservation?

    public init() {}

    public mutating func shouldHide(_ observation: SpaceObservation) -> Bool {
        defer { lastSpaceID = observation.spaceID }
        let exclusive = SpaceOverview.isExclusive(observation.spaceType)
        if exclusive || !observation.windowOnCurrentSpace
            || (!observation.windowSpaceTypes.isEmpty
                && observation.windowSpaceTypes.allSatisfy(SpaceOverview.isExclusive))
        {
            wasBlocked = true
            pending = nil
            needsConfirmation = !exclusive
            return true
        }
        if wasBlocked || (lastSpaceID != nil && lastSpaceID != observation.spaceID) {
            if pending != observation {
                pending = observation
                wasBlocked = true
                needsConfirmation = true
                return true
            }
        }
        wasBlocked = false
        pending = nil
        needsConfirmation = false
        return false
    }
}
