import Foundation
import LovelyGlowCore

@MainActor
final class LocalStore {
    private let fileURL: URL
    private(set) var document: SettingsDocument

    init(fileURL: URL) {
        self.fileURL = fileURL
        if let source = try? String(contentsOf: fileURL, encoding: .utf8) {
            document = SettingsDocument.parse(source)
        } else {
            document = .default
        }
    }

    static func defaultURL() -> URL {
        let directory = OverlaySafety.settingsDirectory(bundleID: Bundle.main.bundleIdentifier)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent("config.toml")
    }

    func update(_ mutate: (inout SettingsDocument) -> Void) {
        mutate(&document)
        persist()
    }

    func persist() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? document.serialized().write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
