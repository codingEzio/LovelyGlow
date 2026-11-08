import CoreGraphics

/// Geometry for one resolved target, including a Combined bounds target.
public enum WindowFollow {
    public static func bounds(for window: FocusedWindow, in snapshots: [CGWindowSnapshot]) -> CGRect? {
        let ids = Set(window.trackingWindowIDs)
        let members = snapshots.filter {
            ids.contains($0.windowID) && $0.pid == window.pid && $0.layer == 0
                && $0.isOnscreen && $0.alpha > 0.05 && FocusResolver.isUsableSize($0.bounds)
        }
        guard members.contains(where: { $0.windowID == window.cgWindowID }) else { return nil }
        return members.reduce(CGRect.null) { $0.union($1.bounds) }
    }
}
