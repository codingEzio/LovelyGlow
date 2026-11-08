import CoreGraphics
import Foundation

public enum FontStyle: String, CaseIterable, Sendable, Hashable {
    case system
    case pixel

    public init(configValue: String) {
        self = FontStyle(rawValue: configValue.lowercased()) ?? .system
    }
}

public enum AppLanguage: String, CaseIterable, Sendable {
    case auto
    case en
    case zhHant = "zh-Hant"
    case zhHans = "zh-Hans"
    case ko
    case ja
    case es
    case ru
    case uk

    public init(configValue: String) {
        self = AppLanguage(rawValue: configValue) ?? .auto
    }
}

public struct SettingsDocument: Equatable, Sendable {
    public var schemaVersion: Int
    public var enabled: Bool
    public var launchAtLogin: Bool
    public var fontStyle: FontStyle
    public var language: AppLanguage
    public var glowAboveDock: Bool
    public var includeAuxiliaryWindows: Bool
    public var animation: GlowAnimationID
    public var animationSpeed: CGFloat
    public var scheme: GlowSchemeID
    public var arrival: GlowArrivalID
    public var style: GlowStyle

    public init(
        schemaVersion: Int = 1,
        enabled: Bool = true,
        launchAtLogin: Bool = false,
        fontStyle: FontStyle = .system,
        language: AppLanguage = .auto,
        glowAboveDock: Bool = true,
        includeAuxiliaryWindows: Bool = false,
        animation: GlowAnimationID = .orbitBreathe,
        animationSpeed: CGFloat = GlowMotion.defaultSpeed,
        scheme: GlowSchemeID = .violetBloom,
        arrival: GlowArrivalID = .instant,
        style: GlowStyle = .default
    ) {
        self.schemaVersion = schemaVersion
        self.enabled = enabled
        self.launchAtLogin = launchAtLogin
        self.fontStyle = fontStyle
        self.language = language
        self.glowAboveDock = glowAboveDock
        self.includeAuxiliaryWindows = includeAuxiliaryWindows
        self.animation = animation
        self.animationSpeed = GlowMotion.clampSpeed(animationSpeed)
        self.scheme = scheme
        self.arrival = arrival
        self.style = style
    }

    public static let `default` = SettingsDocument()

    public static func parse(_ source: String) -> SettingsDocument {
        var values: [String: String] = [:]
        for rawLine in source.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
                continue
            }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let rawValue = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            values[String(key)] = decode(rawValue)
        }

        var document = SettingsDocument.default
        let hasScheme = values["color_scheme"] != nil
        let hasColors = values["light_color"] != nil || values["dark_color"] != nil
        if !hasScheme, hasColors {
            document.scheme = .custom
        }
        if let version = values["schema_version"].flatMap(Int.init) {
            document.schemaVersion = version
        }
        if let enabled = values["enabled"].flatMap(Self.boolean) {
            document.enabled = enabled
        }
        if let launchAtLogin = values["launch_at_login"].flatMap(Self.boolean) {
            document.launchAtLogin = launchAtLogin
        }
        if let font = values["font_style"] {
            document.fontStyle = FontStyle(configValue: font)
        }
        if let language = values["ui_language"] {
            document.language = AppLanguage(configValue: language)
        }
        if let glowAboveDock = values["glow_above_dock"].flatMap(Self.boolean) {
            document.glowAboveDock = glowAboveDock
        }
        if let includeAuxiliaryWindows = values["include_auxiliary_windows"].flatMap(Self.boolean) {
            document.includeAuxiliaryWindows = includeAuxiliaryWindows
        }
        if let animation = values["glow_animation"] {
            document.animation = GlowAnimationID(configValue: animation)
        }
        if let speed = values["glow_speed"].flatMap(Double.init) {
            document.animationSpeed = GlowMotion.clampSpeed(CGFloat(speed))
        }
        if let scheme = values["color_scheme"] {
            document.scheme = GlowSchemeID(configValue: scheme)
        }
        if let arrival = values["glow_arrival"] {
            document.arrival = GlowArrivalID(configValue: arrival)
        }
        if let spread = values["glow_spread"].flatMap(Double.init) {
            document.style.spread = clamp(
                CGFloat(spread), GlowPanelMetrics.minimumSpread, GlowPanelMetrics.maximumSpread)
        }
        if let lineWidth = values["glow_line_width"].flatMap(Double.init) {
            document.style.lineWidth = clamp(CGFloat(lineWidth), 1, 14)
        }
        if let radius = values["glow_corner_radius"].flatMap(Double.init) {
            document.style.cornerRadius = clamp(CGFloat(radius), 0, 40)
        }
        if let opacity = values["glow_opacity"].flatMap(Double.init) {
            document.style.opacity = clamp(CGFloat(opacity), 0.2, 1)
        }
        if let color = values["light_color"].flatMap(RGBAColor.parse) {
            document.style.lightColor = color
        }
        if let color = values["dark_color"].flatMap(RGBAColor.parse) {
            document.style.darkColor = color
        }
        return document
    }

    public func serialized() -> String {
        let lines = [
            "schema_version = \(schemaVersion)",
            "enabled = \(enabled)",
            "launch_at_login = \(launchAtLogin)",
            "font_style = \"\(fontStyle.rawValue)\"",
            "ui_language = \"\(language.rawValue)\"",
            "glow_above_dock = \(glowAboveDock)",
            "include_auxiliary_windows = \(includeAuxiliaryWindows)",
            "glow_animation = \"\(animation.rawValue)\"",
            "glow_speed = \(format(animationSpeed))",
            "color_scheme = \"\(scheme.rawValue)\"",
            "glow_arrival = \"\(arrival.rawValue)\"",
            "glow_spread = \(format(style.spread))",
            "glow_line_width = \(format(style.lineWidth))",
            "glow_corner_radius = \(format(style.cornerRadius))",
            "glow_opacity = \(format(style.opacity))",
            "light_color = \"\(style.lightColor.hex)\"",
            "dark_color = \"\(style.darkColor.hex)\"",
        ]
        return "# Lovely Glow local configuration\n" + lines.joined(separator: "\n") + "\n"
    }

    private static func boolean(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }

    private static func decode(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%g", Double(value))
    }
}

private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
