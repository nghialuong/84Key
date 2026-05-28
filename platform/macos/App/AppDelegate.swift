import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The Obj-C++ input controller bridges to the C++ engine and owns the
    // system-wide CGEvent tap that processes Vietnamese typing.
    private let input = InputController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register defaults and push the saved options into the engine globals
        // before the tap starts processing keys.
        AppSettings.shared.attach(input)
        let started = input.start()
        // Returning false here is expected until Accessibility permission is
        // granted; the onboarding flow that requests it is a later task.
        NSLog("84Key launched: event tap started = %@ (accessibility = %@)",
              started ? "YES" : "NO",
              input.hasAccessibilityPermission() ? "YES" : "NO")
    }

    func applicationWillTerminate(_ notification: Notification) {
        input.stop()
    }
}
