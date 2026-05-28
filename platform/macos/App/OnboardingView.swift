import SwiftUI
import AppKit

/// First-run onboarding shown when Accessibility permission is missing. 84Key is
/// a menu-bar agent (LSUIElement), so there is no main window scene; this is
/// presented imperatively through `OnboardingController`, which owns the NSWindow
/// and polls for the granted permission.
struct OnboardingView: View {
    /// Called when the user asks to open Accessibility settings (triggers the
    /// system prompt and/or opens the Privacy pane).
    let onOpenSettings: () -> Void
    /// Lets the user dismiss the window without granting now.
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to 84Key")
                        .font(.title2).bold()
                    Text("Vietnamese typing for macOS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("84Key needs Accessibility permission to process keyboard input.")
                    .font(.headline)
                Text("To place Vietnamese diacritics, 84Key reads and replaces the text in the field you are typing in. macOS requires Accessibility permission for this kind of input handling. 84Key does not send your text anywhere.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Turn off other Vietnamese input methods", systemImage: "exclamationmark.triangle")
                        .font(.subheadline).bold()
                    Text("Running 84Key alongside OpenKey, EVKey, or the built-in macOS Vietnamese input source causes duplicated or garbled characters. Please disable the others before typing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Waiting for permission… 84Key starts automatically once granted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Later", action: onSkip)
                Spacer()
                Button("Open Accessibility Settings", action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

/// Owns the onboarding NSWindow, the permission poll timer, and the hand-off to
/// start the event tap. Created and retained by `AppDelegate`.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private let input: InputController
    /// Invoked (on the main actor) when permission is detected so the app can
    /// start the tap. Returns whether the tap actually started.
    private let onGranted: () -> Void

    private var window: NSWindow?
    private var pollTimer: Timer?

    init(input: InputController, onGranted: @escaping () -> Void) {
        self.input = input
        self.onGranted = onGranted
        super.init()
    }

    /// Show the onboarding window and begin polling for permission.
    func present() {
        if input.hasAccessibilityPermission() {
            // Nothing to onboard; let the caller start immediately.
            onGranted()
            return
        }

        if window == nil {
            let view = OnboardingView(
                onOpenSettings: { [weak self] in self?.openAccessibilitySettings() },
                onSkip: { [weak self] in self?.dismiss() }
            )
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "Welcome to 84Key"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            window = win
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        startPolling()
    }

    private func openAccessibilitySettings() {
        // Surfaces the system "open System Settings" prompt for our app.
        _ = input.requestAccessibilityPermission()
        // Also deep-link to the Accessibility privacy pane as a fallback.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop; hop to the main actor for the
            // permission check and UI/tap mutation.
            Task { @MainActor in self?.checkPermission() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func checkPermission() {
        guard input.hasAccessibilityPermission() else { return }
        onGranted()
        dismiss()
    }

    /// Close the window, stop polling, and restore agent (no-Dock) activation.
    func dismiss() {
        pollTimer?.invalidate()
        pollTimer = nil
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        // Return to accessory so the app stays a pure menu-bar agent.
        NSApp.setActivationPolicy(.accessory)
    }

    // User closed the window with the title-bar control.
    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
