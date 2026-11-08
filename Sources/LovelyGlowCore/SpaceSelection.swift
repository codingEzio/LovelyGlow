import CoreGraphics

public struct DisplaySpaceSnapshot {
    public var bounds: CGRect
    public var spaceID: UInt64
    public var spaceType: Int32

    public init(bounds: CGRect, spaceID: UInt64, spaceType: Int32) {
        self.bounds = bounds
        self.spaceID = spaceID
        self.spaceType = spaceType
    }
}

public enum SpaceSelection {
    public static func observation(
        for window: CGRect?, displays: [DisplaySpaceSnapshot], fallback: SpaceObservation
    ) -> SpaceObservation {
        // Mission Control/App Exposé intentionally hide all rims. Native
        // fullscreen belongs to one display and must not suppress another.
        if let overview = displays.first(where: { $0.spaceType == SpaceOverview.systemSpace }) {
            return SpaceObservation(spaceID: overview.spaceID, spaceType: overview.spaceType)
        }
        guard let window,
            let index = WindowGeometry.displayIndex(for: window, in: displays.map(\.bounds))
        else { return fallback }
        let display = displays[index]
        return SpaceObservation(spaceID: display.spaceID, spaceType: display.spaceType)
    }
}
