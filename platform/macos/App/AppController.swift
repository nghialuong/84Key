import AppKit
import Combine

/// Owns the input controller and coordinates startup, the Accessibility-permission
/// lifecycle, and the run-at-login item. Publishes `isRunning` / `hasPermission`
/// so the menu bar and onboarding reflect the real state.
///
/// Detecting permission by **trying to start the event tap** is deliberate: for
/// ad-hoc / development builds `AXIsProcessTrusted()` can lag (the TCC grant is
/// tied to the code signature, which changes on every rebuild), so a successful
/// `start()` is the only reliable proof that typing will actually work.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let input = InputController()

    @Published private(set) var isRunning = false
    @Published private(set) var hasPermission = false

    private var pollTimer: Timer?
    private var loginObserver: AnyCancellable?
    private var onboarding: OnboardingController?

    func startup() {
        let settings = AppSettings.shared
        settings.attach(input)

        let dictsLoaded = input.loadDictionaries()
        NSLog("84Key dictionaries loaded = %@", dictsLoaded ? "YES" : "NO")

        LoginItemManager.sync(enabled: settings.runOnStartup)
        loginObserver = settings.$runOnStartup
            .dropFirst()
            .sink { LoginItemManager.sync(enabled: $0) }

        refresh()
        if !isRunning {
            presentOnboarding()
        }
        startPolling()
    }

    func shutdown() {
        pollTimer?.invalidate()
        pollTimer = nil
        input.stop()
    }

    /// Re-check permission and (re)start the tap if it isn't running yet. Returns
    /// whether the tap is now running.
    @discardableResult
    func refresh() -> Bool {
        hasPermission = input.hasAccessibilityPermission()
        if !input.isRunning() {
            _ = input.start()
        }
        let running = input.isRunning()
        isRunning = running
        if running {
            onboarding?.dismiss()
            onboarding = nil
        }
        return running
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.refresh() { self.stopPolling() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func openAccessibilitySettings() {
        _ = input.requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func presentOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingController(controller: self)
        }
        onboarding?.present()
    }

    /// Quit and relaunch. After granting Accessibility to a dev/ad-hoc build, a
    /// fresh process is the most reliable way to pick up the new grant.
    func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
