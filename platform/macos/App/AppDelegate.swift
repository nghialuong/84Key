import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The Obj-C++ input controller bridges to the C++ engine and owns the
    // system-wide CGEvent tap that processes Vietnamese typing.
    private let input = InputController()

    // Retained so its NSWindow and poll timer outlive the launch method.
    private var onboarding: OnboardingController?

    // Observes the "launch at login" toggle to keep the SMAppService login
    // item in sync.
    private var loginItemObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register defaults and push the saved options into the engine globals
        // before the tap starts processing keys.
        let settings = AppSettings.shared
        settings.attach(input)

        // Keep the macOS login item in sync with the persisted preference once
        // at launch, then on every change of the toggle.
        LoginItemManager.sync(enabled: settings.runOnStartup)
        loginItemObserver = settings.$runOnStartup
            .dropFirst() // skip the value emitted while wiring up
            .sink { LoginItemManager.sync(enabled: $0) }

        if input.hasAccessibilityPermission() {
            startTap()
        } else {
            // First run (or permission revoked): guide the user through granting
            // Accessibility, then start the tap automatically once it's granted.
            let controller = OnboardingController(input: input) { [weak self] in
                self?.startTap()
            }
            onboarding = controller
            controller.present()
        }
    }

    /// Start the event tap and log the result.
    private func startTap() {
        let started = input.start()
        NSLog("84Key event tap started = %@ (accessibility = %@)",
              started ? "YES" : "NO",
              input.hasAccessibilityPermission() ? "YES" : "NO")
    }

    func applicationWillTerminate(_ notification: Notification) {
        input.stop()
    }
}
