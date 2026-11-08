import Foundation
import Testing
@testable import LovelyGlowCore

struct ProductIdentityTests {
    @Test func productConfKeepsAccessibilityIdentity() throws {
        let text = try String(contentsOf: productConfURL(), encoding: .utf8)
        #expect(text.contains("BUNDLE_ID=\(OverlaySafety.ownBundleID)"))
        #expect(text.contains("APP_BUNDLE_NAME=\(OverlaySafety.appBundleName)"))
        #expect(text.contains("EXECUTABLE_NAME=\(OverlaySafety.appBundleName)"))
        // Signing stays in the private config; never duplicate personal certificate data in source.
        let signing = try #require(text.split(separator: "\n").first { $0.hasPrefix("SIGNING_IDENTITY=") })
        if productConfURL().lastPathComponent == "product.public.conf" {
            #expect(signing == "SIGNING_IDENTITY=\"\"")
        } else {
            #expect(signing != "SIGNING_IDENTITY=\"\"")
        }
    }

    @Test func installScriptKeepsTheSameBundleAndRequirement() throws {
        let text = try String(contentsOf: scriptURL("install.sh"), encoding: .utf8)
        #expect(text.contains("APP_PARENT=\"$HOME/Applications\""))
        #expect(text.contains("APP_BUNDLE=\"$APP_PARENT/$APP_BUNDLE_NAME.app\""))
        #expect(text.contains("candidate_requirement"))
        #expect(text.contains("installed_requirement"))
        #expect(text.contains("candidate_requirement\" == \"$installed_requirement\""))
    }

    @Test func overlayNeverReportsAFullyOpaqueShownAlpha() {
        #expect(OverlaySafety.isShownAlphaNonOccluding)
        #expect(OverlaySafety.shownAlpha < 1)
        #expect(OverlaySafety.hiddenAlpha == 0)
    }

    @Test func glowDefaultsAboveTheDockAndBelowTheMenuBar() {
        let dock = OverlaySafety.dockLevel
        let menu = OverlaySafety.menuBarLevel
        let above = OverlaySafety.overlayLevel(aboveDock: true)
        let below = OverlaySafety.overlayLevel(aboveDock: false)
        #expect(above > dock)
        #expect(above < menu)
        #expect(below < dock)
        #expect(below > 0)
    }

    private func productConfURL() -> URL {
        let privateURL = repositoryRoot().appendingPathComponent("config/product.conf")
        return FileManager.default.fileExists(atPath: privateURL.path)
            ? privateURL : repositoryRoot().appendingPathComponent("config/product.public.conf")
    }

    private func scriptURL(_ name: String) -> URL {
        repositoryRoot().appendingPathComponent("script/\(name)")
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
