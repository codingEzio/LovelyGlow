import AppKit
import CoreText
import Foundation
import LovelyGlowCore

enum LovelyFonts {
    static let postScriptName = "DeparturePixelZhCompact-Regular"
    static let compactFamilyName = "DeparturePixelZh Compact"
    private static let bundledFileName = "DeparturePixelZhCompact-Regular.ttf"

    private struct FontDescriptorBox: @unchecked Sendable {
        let value: CTFontDescriptor
    }

    private static let resolvedBundledURL: URL? = {
        bundledFontURL(named: bundledFileName)
    }()

    private static let bundledDescriptor: FontDescriptorBox? = {
        guard let resolvedBundledURL, let descriptor = descriptor(at: resolvedBundledURL) else { return nil }
        return FontDescriptorBox(value: descriptor)
    }()

    private static let bundledRegistration: Void = {
        if let resolvedBundledURL {
            CTFontManagerRegisterFontsForURL(resolvedBundledURL as CFURL, .process, nil)
        }
    }()

    static func registerBundledFonts() {
        _ = bundledRegistration
    }

    static func uiFont(ofSize size: CGFloat, style: FontStyle, weight: NSFont.Weight = .regular) -> NSFont {
        if style == .system {
            return .systemFont(ofSize: size, weight: weight)
        }
        return pixelFont(ofSize: size, weight: weight)
    }

    static func contentFont(ofSize size: CGFloat, style: FontStyle, weight: NSFont.Weight = .regular) -> NSFont {
        uiFont(ofSize: size, style: style, weight: weight)
    }

    static func monoFont(ofSize size: CGFloat, style: FontStyle, weight: NSFont.Weight = .regular) -> NSFont {
        if style == .system {
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
        return pixelFont(ofSize: size, weight: weight)
    }

    private static func pixelFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        _ = bundledRegistration
        let font: NSFont
        if let descriptor = bundledDescriptor?.value {
            font = CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
        } else {
            font = fallbackFont(ofSize: size)
        }
        guard weight >= .semibold else { return font }
        return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }

    static func bundledURL() -> URL? { resolvedBundledURL }

    private static func bundledFontURL(named fileName: String) -> URL? {
        let fileNameNS = fileName as NSString
        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Fonts", isDirectory: true)
                .appendingPathComponent(fileName),
            Bundle.main.url(
                forResource: fileNameNS.deletingPathExtension,
                withExtension: fileNameNS.pathExtension,
                subdirectory: "Fonts"
            ),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/Fonts", isDirectory: true)
                .appendingPathComponent(fileName),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func descriptor(at url: URL) -> CTFontDescriptor? {
        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                as? [CTFontDescriptor]
        else { return nil }
        return descriptors.first
    }

    private static func fallbackFont(ofSize size: CGFloat) -> NSFont {
        .systemFont(ofSize: size)
    }
}
