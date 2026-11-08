import Foundation
import LovelyGlowCore

enum ProductIdentity {
    static let bundleID = OverlaySafety.runtimeBundleID(Bundle.main.bundleIdentifier)

    static var displayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            !name.isEmpty
        {
            return name
        }
        return "Lovely Glow"
    }
}
