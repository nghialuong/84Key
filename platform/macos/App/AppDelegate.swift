import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppController.shared.startup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.shutdown()
    }
}
