import CoreGraphics
import Foundation

public struct RGBAColor: Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var hex: String {
        let clamp: (CGFloat) -> Int = { Int((min(max($0, 0), 1) * 255).rounded()) }
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", clamp(red), clamp(green), clamp(blue))
        }
        return String(
            format: "#%02X%02X%02X%02X",
            clamp(red),
            clamp(green),
            clamp(blue),
            clamp(alpha)
        )
    }

    public func mixed(with other: RGBAColor, amount: CGFloat) -> RGBAColor {
        let t = min(max(amount, 0), 1)
        return RGBAColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }

    public func withAlpha(_ value: CGFloat) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: min(max(value, 0), 1))
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let champagne = RGBAColor.parse("#FFD4A8")!

    public static func parse(_ raw: String) -> RGBAColor? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8,
              let value = UInt32(hex, radix: 16)
        else { return nil }
        if hex.count == 6 {
            return RGBAColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }
        return RGBAColor(
            red: CGFloat((value >> 24) & 0xFF) / 255,
            green: CGFloat((value >> 16) & 0xFF) / 255,
            blue: CGFloat((value >> 8) & 0xFF) / 255,
            alpha: CGFloat(value & 0xFF) / 255
        )
    }
}
