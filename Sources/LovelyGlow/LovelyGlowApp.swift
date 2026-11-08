import AppKit
import LovelyGlowCore

@main
enum LovelyGlowMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = LovelyGlowDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class LovelyGlowDelegate: NSObject, NSApplicationDelegate {
    private var runtime: GlowRuntime?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LovelyFonts.registerBundledFonts()
        let store = LocalStore(fileURL: LocalStore.defaultURL())
        let runtime = GlowRuntime(store: store)
        statusItem = StatusItemController(runtime: runtime)
        self.runtime = runtime
        runtime.start()
        if store.document.launchAtLogin {
            try? LaunchAtLogin.setEnabled(true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.tracker.stop()
    }
}
