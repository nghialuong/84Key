import SwiftUI
import AppKit

/// First-run onboarding shown when 84Key cannot yet process typing (Accessibility
/// permission missing or not yet effective). 84Key is a menu-bar agent
/// (LSUIElement), so this is presented imperatively by `OnboardingController`.
/// `AppController` polls in the background and dismisses it once the tap starts.
struct OnboardingView: View {
    let onOpenSettings: () -> Void
    let onRelaunch: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to 84Key").font(.title2).bold()
                    Text("Vietnamese typing for macOS")
                        .font(.subheadline).foregroundStyle(.secondary)
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
                    Label("Two steps", systemImage: "list.number")
                        .font(.subheadline).bold()
                    Text("1. Click “Open Accessibility Settings” and enable 84Key.\n2. Click “Restart 84Key” so it picks up the new permission. (Development builds need this; a signed release will not.)")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Turn off other Vietnamese input methods", systemImage: "exclamationmark.triangle")
                        .font(.subheadline).bold()
                    Text("OpenKey, EVKey, or the built-in macOS Vietnamese source running at the same time cause duplicated or garbled characters.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Waiting for permission… 84Key starts automatically once it takes effect.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Later", action: onSkip)
                Spacer()
                Button("Restart 84Key", action: onRelaunch)
                Button("Open Accessibility Settings", action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 520, alignment: .topLeading)
    }
}

/// Owns the onboarding NSWindow. Polling/permission logic lives in AppController.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private weak var app: AppController?
    private var window: NSWindow?

    init(controller: AppController) {
        self.app = controller
        super.init()
    }

    func present() {
        if window == nil {
            let view = OnboardingView(
                onOpenSettings: { [weak self] in self?.app?.openAccessibilitySettings() },
                onRelaunch: { [weak self] in self?.app?.relaunch() },
                onSkip: { [weak self] in self?.dismiss() }
            )
            let hosting = NSHostingController(rootView: view)
            // Don't let SwiftUI drive the window size (a flexible-height root makes
            // NSHostingController ping-pong the Update Constraints pass until AppKit
            // throws and the app crashes). Fix the window size instead.
            hosting.sizingOptions = []
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hosting
            win.title = "Welcome to 84Key"
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
