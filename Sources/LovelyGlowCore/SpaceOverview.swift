import Foundation

/// WindowServer space types we actually branch on. Other values stay unknown.
public enum SpaceOverview {
    public static let userSpace: Int32 = 0
    /// Native app fullscreen (separate Space).
    public static let fullscreenSpace: Int32 = 1
    /// Mission Control, App Exposé, and other system overlay spaces.
    public static let systemSpace: Int32 = 2
    /// Fullscreen / tiled Spaces on some macOS builds.
    public static let tiledSpace: Int32 = 4

    public static func isExclusive(_ spaceType: Int32) -> Bool {
        spaceType == systemSpace || spaceType == fullscreenSpace || spaceType == tiledSpace
    }

    public static func shouldHideGlow(
        spaceType: Int32,
        frontIsSystemChrome: Bool
    ) -> Bool {
        if isExclusive(spaceType) { return true }
        if frontIsSystemChrome && spaceType != userSpace { return true }
        return false
    }

    /// Overlay may follow the user Space. Exclusive Spaces keep it ordered out.
    public static func shouldRejoin(spaceType: Int32) -> Bool {
        !isExclusive(spaceType)
    }
}
