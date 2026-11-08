import Foundation

/// Named palettes taken from published glow/aurora/neon systems, then split
/// into a darker light-mode rim and a luminous dark-mode rim.
public enum GlowSchemeID: String, CaseIterable, Sendable {
    case violetBloom
    case auroraTeal
    case cyberNeon
    case northern
    case sunset
    case champagne
    case moonlight
    case ember
    case jade
    case custom

    public init(configValue: String) {
        self = GlowSchemeID(rawValue: configValue) ?? .violetBloom
    }
}

public struct GlowScheme: Equatable, Sendable, Identifiable {
    public var id: GlowSchemeID
    public var light: GlowPalette
    public var dark: GlowPalette
    public var source: String

    public init(id: GlowSchemeID, light: GlowPalette, dark: GlowPalette, source: String) {
        self.id = id
        self.light = light
        self.dark = dark
        self.source = source
    }

    public func palette(isDark: Bool) -> GlowPalette {
        isDark ? dark : light
    }
}

public enum GlowSchemeCatalog {
    public static let all: [GlowScheme] = [
        GlowScheme(
            id: .violetBloom,
            light: palette("#6B3DFF", highlight: "#8B6CFF", warmth: "#C4A8FF"),
            dark: palette("#A78BFA", highlight: "#F4D6FF", warmth: "#FFD8F4"),
            source: "PromptsRush Aurora / current Lovely Glow violet"
        ),
        GlowScheme(
            id: .auroraTeal,
            light: palette("#6B46C1", highlight: "#7C5CFF", warmth: "#2BA8A1"),
            dark: palette("#3FD0C9", highlight: "#A06BFF", warmth: "#7DE8E2"),
            source: "CSS Crème Aurora (#3FD0C9 / #A06BFF)"
        ),
        GlowScheme(
            id: .cyberNeon,
            light: palette("#C41E7A", highlight: "#E23A96", warmth: "#008FA3"),
            dark: palette("#00E5FF", highlight: "#FF2E97", warmth: "#7AFFFF"),
            source: "CSS Crème Cyberpunk Neon (#FF2E97 / #00E5FF)"
        ),
        GlowScheme(
            id: .northern,
            light: palette("#5B21B6", highlight: "#7C3AED", warmth: "#0F766E"),
            dark: palette("#2DD4BF", highlight: "#8B5CF6", warmth: "#EC4899"),
            source: "Superdesign Aurora UI (#8B5CF6 / #2DD4BF / #EC4899)"
        ),
        GlowScheme(
            id: .sunset,
            light: palette("#6D28D9", highlight: "#C026D3", warmth: "#C2410C"),
            dark: palette("#F59E0B", highlight: "#EC4899", warmth: "#7C3AED"),
            source: "Froiden Aurora Border (#7C3AED / #EC4899 / #F59E0B)"
        ),
        GlowScheme(
            id: .champagne,
            light: palette("#7C3AED", highlight: "#A66CFF", warmth: "#B8860B"),
            dark: palette("#FBE7C6", highlight: "#A66CFF", warmth: "#D4AF37"),
            source: "Filmora Violet Champagne Soiree (#A66CFF / #D4AF37 / #FBE7C6)"
        ),
        GlowScheme(
            id: .moonlight,
            light: palette("#254E9B", highlight: "#4B72CA", warmth: "#738FC9"),
            dark: palette("#78A9FF", highlight: "#C9DBFF", warmth: "#87D3F2"),
            source: "Lovely Glow original"
        ),
        GlowScheme(
            id: .ember,
            light: palette("#AD462C", highlight: "#D2663E", warmth: "#C47A2B"),
            dark: palette("#FF8D63", highlight: "#FFC29B", warmth: "#FFD171"),
            source: "Lovely Glow original"
        ),
        GlowScheme(
            id: .jade,
            light: palette("#136B5A", highlight: "#25856A", warmth: "#3B8E88"),
            dark: palette("#66DDB5", highlight: "#A4F5D6", warmth: "#7CE9E2"),
            source: "Lovely Glow original"
        ),
    ]

    public static func scheme(_ id: GlowSchemeID) -> GlowScheme? {
        all.first { $0.id == id }
    }

    public static func palette(id: GlowSchemeID, isDark: Bool, custom: GlowPalette) -> GlowPalette {
        guard id != .custom, let scheme = scheme(id) else { return custom }
        return scheme.palette(isDark: isDark)
    }

    private static func palette(_ base: String, highlight: String, warmth: String) -> GlowPalette {
        GlowPalette(
            base: RGBAColor.parse(base)!,
            highlight: RGBAColor.parse(highlight)!,
            warmth: RGBAColor.parse(warmth)!
        )
    }
}
