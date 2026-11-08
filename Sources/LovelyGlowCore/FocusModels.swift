import CoreGraphics
import Foundation

public struct RunningAppSnapshot: Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String?
    public var name: String
    public var isHidden: Bool
    public var isRegular: Bool

    public init(
        pid: Int32,
        bundleID: String?,
        name: String,
        isHidden: Bool,
        isRegular: Bool = true
    ) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.isHidden = isHidden
        self.isRegular = isRegular
    }
}

public struct AXWindowSnapshot: Equatable, Sendable {
    public var pid: Int32
    public var bounds: CGRect
    public var isMinimized: Bool
    public var isFullscreen: Bool
    public var subrole: String?

    public init(
        pid: Int32,
        bounds: CGRect,
        isMinimized: Bool,
        isFullscreen: Bool,
        subrole: String? = nil
    ) {
        self.pid = pid
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.subrole = subrole
    }
}

public struct CGWindowSnapshot: Equatable, Sendable {
    public var windowID: UInt32
    public var pid: Int32
    public var layer: Int
    public var alpha: CGFloat
    public var bounds: CGRect
    public var isOnscreen: Bool
    public var name: String?

    public init(
        windowID: UInt32,
        pid: Int32,
        layer: Int,
        alpha: CGFloat,
        bounds: CGRect,
        isOnscreen: Bool,
        name: String? = nil
    ) {
        self.windowID = windowID
        self.pid = pid
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
        self.isOnscreen = isOnscreen
        self.name = name
    }
}

public struct DisplaySnapshot: Equatable, Sendable {
    public var bounds: CGRect
    public var visible: CGRect

    public init(bounds: CGRect, visible: CGRect? = nil) {
        self.bounds = bounds
        self.visible = visible ?? bounds
    }
}

public struct FocusedWindow: Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String?
    public var cgWindowID: UInt32?
    public var bounds: CGRect
    public var trackingWindowIDs: [UInt32]

    public init(pid: Int32, bundleID: String?, cgWindowID: UInt32?, bounds: CGRect, trackingWindowIDs: [UInt32]? = nil)
    {
        self.pid = pid
        self.bundleID = bundleID
        self.cgWindowID = cgWindowID
        self.bounds = bounds
        self.trackingWindowIDs = trackingWindowIDs ?? cgWindowID.map { [$0] } ?? []
    }
}

public enum HiddenReason: String, Equatable, Sendable {
    case disabled
    case noFrontApp
    case systemApp
    case hiddenApp
    case noWindow
    case fullscreen
    case minimized
    case tooSmall
    case missionControl
}

public enum GlowTargetRole: String, Equatable, Sendable {
    case focused
    case sibling
}

public struct GlowTarget: Equatable, Sendable {
    public var window: FocusedWindow
    public var role: GlowTargetRole
    public var schemeID: GlowSchemeID?
    public var animationID: GlowAnimationID?

    public init(
        window: FocusedWindow,
        role: GlowTargetRole,
        schemeID: GlowSchemeID? = nil,
        animationID: GlowAnimationID? = nil
    ) {
        self.window = window
        self.role = role
        self.schemeID = schemeID
        self.animationID = animationID
    }
}

public struct GlowPresentation: Equatable, Sendable {
    public var targets: [GlowTarget]

    public init(targets: [GlowTarget]) {
        self.targets = targets
    }

    public init(focused: FocusedWindow, siblings: [FocusedWindow] = []) {
        var next: [GlowTarget] = [GlowTarget(window: focused, role: .focused)]
        next.append(contentsOf: siblings.map { GlowTarget(window: $0, role: .sibling) })
        self.targets = next
    }

    public var focused: GlowTarget? {
        targets.first { $0.role == .focused }
    }
}

public enum FocusDecision: Equatable, Sendable {
    case hidden(HiddenReason)
    case visible(GlowPresentation)
    /// Our popover, Cmd+Tab, and Spotlight keep the last glow. Mission Control hides.
    case hold

    public static func glowing(_ focused: FocusedWindow, siblings: [FocusedWindow] = []) -> FocusDecision {
        .visible(GlowPresentation(focused: focused, siblings: siblings))
    }
}
