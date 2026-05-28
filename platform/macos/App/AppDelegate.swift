import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The Obj-C++ input controller bridges to the C++ engine. The event tap is
    // wired up in T8; for the skeleton we just confirm the bridge links and runs.
    private let input = InputController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("84Key launched: %@", input.engineStatus())
    }
}
