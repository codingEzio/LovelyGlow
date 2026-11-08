// swift-tools-version: 6.2
import Foundation
import PackageDescription

let rootURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let privateConfigURL = rootURL.appendingPathComponent("config/product.conf")
let configURL =
    FileManager.default.fileExists(atPath: privateConfigURL.path)
    ? privateConfigURL : rootURL.appendingPathComponent("config/product.public.conf")
let allowedProductKeys: Set<String> = [
    "PROJECT_NAME", "DISPLAY_NAME", "APP_BUNDLE_NAME", "EXECUTABLE_NAME", "BUNDLE_ID",
    "VERSION", "BUILD_NUMBER", "MIN_SYSTEM_VERSION", "SIGNING_IDENTITY",
]
let productConfig = try String(contentsOf: configURL, encoding: .utf8)
    .split(whereSeparator: \.isNewline)
    .reduce(into: [String: String]()) { values, rawLine in
        let line = String(rawLine)
        guard !line.isEmpty, !line.hasPrefix("#") else { return }
        let fields = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        precondition(fields.count == 2, "Invalid product config line: \(line)")
        let key = String(fields[0])
        precondition(allowedProductKeys.contains(key), "Unknown product config key: \(key)")
        precondition(values[key] == nil, "Duplicate product config key: \(key)")
        var value = String(fields[1])
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        values[key] = value
    }
let packageName = productConfig["PROJECT_NAME"]!
let executableName = productConfig["EXECUTABLE_NAME"]!
let supportedPlatforms: [SupportedPlatform] =
    switch productConfig["MIN_SYSTEM_VERSION"]! {
    case "27.0": [.macOS("27.0")]
    default: preconditionFailure("Unsupported MIN_SYSTEM_VERSION")
    }

let package = Package(
    name: packageName,
    platforms: supportedPlatforms,
    products: [
        .library(name: "LovelyGlowCore", targets: ["LovelyGlowCore"]),
        .executable(name: executableName, targets: ["LovelyGlow"]),
    ],
    targets: [
        .target(
            name: "LovelyGlowCore",
            path: "Sources/LovelyGlowCore"
        ),
        .executableTarget(
            name: "LovelyGlow",
            dependencies: ["LovelyGlowCore"],
            path: "Sources/LovelyGlow",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "LovelyGlowTests",
            dependencies: ["LovelyGlowCore"],
            path: "Tests/LovelyGlowTests"
        ),
    ]
)
