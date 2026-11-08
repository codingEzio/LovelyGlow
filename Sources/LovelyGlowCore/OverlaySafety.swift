import CoreGraphics
import Foundation

public enum OverlaySafety {
    public static let shownAlpha: CGFloat = 0.999
    public static let hiddenAlpha: CGFloat = 0
    public static let ownBundleID = "com.alex.LovelyGlow"
    public static let developmentBundleID = "com.github.codingEzio.LovelyGlow.Development"

    public static func runtimeBundleID(_ bundleID: String?) -> String {
        bundleID == developmentBundleID ? developmentBundleID : ownBundleID
    }

    public static func settingsDirectory(bundleID: String?) -> String {
        bundleID == developmentBundleID ? developmentBundleID : ownBundleID
    }

    public static let appBundleName = "LovelyGlow"
    public static let installParent = "~/Applications"

    public static var isShownAlphaNonOccluding: Bool {
        shownAlpha > 0 && shownAlpha < 1
    }

    public static var dockLevel: Int32 {
        CGWindowLevelForKey(.dockWindow)
    }

    public static var menuBarLevel: Int32 {
        CGWindowLevelForKey(.mainMenuWindow)
    }

    public static func overlayLevel(aboveDock: Bool) -> Int32 {
        if aboveDock {
            return min(dockLevel + 1, menuBarLevel - 1)
        }
        return dockLevel - 1
    }
}
