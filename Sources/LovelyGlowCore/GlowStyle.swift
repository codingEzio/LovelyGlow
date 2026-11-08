import CoreGraphics
import Foundation

public struct GlowStyle: Equatable, Sendable {
    public var spread: CGFloat
    public var lineWidth: CGFloat
    public var cornerRadius: CGFloat
    public var opacity: CGFloat
    public var lightColor: RGBAColor
    public var darkColor: RGBAColor

    public init(
        spread: CGFloat,
        lineWidth: CGFloat,
        cornerRadius: CGFloat,
        opacity: CGFloat,
        lightColor: RGBAColor,
        darkColor: RGBAColor
    ) {
        self.spread = spread
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.lightColor = lightColor
        self.darkColor = darkColor
    }

    public static let `default` = GlowStyle(
        spread: 14,
        lineWidth: 2.8,
        cornerRadius: WindowChrome.standardRadius,
        opacity: 0.9,
        lightColor: RGBAColor.parse("#6B3DFF")!,
        darkColor: RGBAColor.parse("#FFD8F4")!
    )

    public func color(isDark: Bool) -> RGBAColor {
        isDark ? darkColor : lightColor
    }

    public func derivedPalette(isDark: Bool) -> GlowPalette {
        let base = color(isDark: isDark)
        return GlowPalette(
            base: base,
            highlight: base.mixed(with: .white, amount: isDark ? 0.28 : 0.18),
            warmth: base.mixed(with: .champagne, amount: isDark ? 0.22 : 0.16)
        )
    }

    public func palette(isDark: Bool, scheme: GlowSchemeID = .custom) -> GlowPalette {
        GlowSchemeCatalog.palette(id: scheme, isDark: isDark, custom: derivedPalette(isDark: isDark))
    }

    public func strokeRadius(forWindowBounds bounds: CGRect) -> CGFloat {
        WindowChrome.radius(cornerRadius, forWindowBounds: bounds)
    }

    /// Keeps WindowServer values in their reported coordinate space. The
    /// visual boost is applied once, when overlay geometry is laid out.
    public func withReportedCornerRadius(_ radius: CGFloat?) -> GlowStyle {
        guard let radius else { return self }
        var copy = self
        copy.cornerRadius = radius
        return copy
    }
}

public enum WindowChrome {
    /// WindowServer still reports 16 for titled windows. Drawing uses a
    /// slightly larger circular radius so the rim stays smooth without a dented G2 pull.
    public static let standardRadius: CGFloat = 16
    public static let continuousBoost: CGFloat = 1.55

    public static func radius(forWindowBounds bounds: CGRect) -> CGFloat {
        radius(standardRadius, forWindowBounds: bounds)
    }

    public static func radius(_ cornerRadius: CGFloat, forWindowBounds bounds: CGRect) -> CGFloat {
        let visual = visualRadius(cornerRadius)
        let limit = min(bounds.width, bounds.height) / 2
        return min(max(visual, 0), max(limit, 0))
    }

    /// Reported WindowServer / style radius → the radius we actually draw.
    public static func visualRadius(_ reported: CGFloat) -> CGFloat {
        let base = reported > minimumReportedRadius ? reported : standardRadius
        return base * continuousBoost
    }

    public static let minimumReportedRadius: CGFloat = 1.5
    public static let minimumConcentricRadius: CGFloat = 4

    public static func resolvedRadius(values: [CGFloat], fallback: CGFloat = standardRadius) -> CGFloat {
        let usable = values.filter { $0 > minimumReportedRadius }
        guard !usable.isEmpty else { return fallback }
        return usable.reduce(0, +) / CGFloat(usable.count)
    }

    /// Parallel-curve radius for a hole that sits outside (positive) or inside the window.
    public static func concentricRadius(_ radius: CGFloat, expansion: CGFloat) -> CGFloat {
        max(radius + expansion, minimumConcentricRadius)
    }
}

public struct GlowPalette: Equatable, Sendable {
    public var base: RGBAColor
    public var highlight: RGBAColor
    public var warmth: RGBAColor

    public init(base: RGBAColor, highlight: RGBAColor, warmth: RGBAColor) {
        self.base = base
        self.highlight = highlight
        self.warmth = warmth
    }
}
