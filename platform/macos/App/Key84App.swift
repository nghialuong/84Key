import SwiftUI

@main
struct Key84App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var app = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings, app: app)
        } label: {
            // Reflect real state: VI/EN when active, a warning when 84Key can't
            // process typing yet (Accessibility permission needed).
            if app.isRunning {
                // Colored brand glyphs (pink V / blue E), 18pt — drawn in their
                // own colors via .original so the menu bar doesn't tint them.
                Image(settings.language == 1 ? "MenubarV" : "MenubarE")
                    .renderingMode(.original)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }

        Settings {
            SettingsView()
        }
        // Window follows the content's fixed size → not user-resizable; only the
        // sidebar divider can move.
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController
    @Environment(\.openSettings) private var openSettings

    /// Radio-style binding for a language mode: turning a row on selects that
    /// mode; turning the active row off is ignored (one mode is always on).
    private func languageBinding(_ lang: Int) -> Binding<Bool> {
        Binding(
            get: { settings.language == lang },
            set: { isOn in if isOn { settings.language = lang } }
        )
    }

    var body: some View {
        if app.isRunning {
            // Show both modes with a native checkmark on the active one (like the
            // macOS Input Source menu) — clearer than a "Chuyển sang…" toggle and
            // lets the user pick a mode directly. The configured switch hotkey
            // (default ⌃⌘Space) is surfaced on the *inactive* row, where pressing
            // it takes you, so it still reads as a toggle and stays in sync with
            // Settings. The engine's global tap consumes the combo before it
            // reaches the app, so this shortcut is hint-only and can't double-fire.
            Toggle("Tiếng Việt", isOn: languageBinding(1))
                .keyboardShortcut(settings.language == 1 ? nil : Key84Shortcut.keyboardShortcut(settings.switchKey))
            Toggle("English", isOn: languageBinding(0))
                .keyboardShortcut(settings.language == 0 ? nil : Key84Shortcut.keyboardShortcut(settings.switchKey))
        } else {
            Text(app.hasPermission
                 ? "Đã cấp quyền — bấm Khởi động lại để kích hoạt"
                 : "⚠︎ Cần quyền Trợ năng (Accessibility)")
            Button("Mở cài đặt Trợ năng…") { app.openAccessibilitySettings() }
            Button("Khởi động lại 84Key") { app.relaunch() }
        }

        Divider()
        Button("Cài đặt…") { openSettingsWindow() }
            .keyboardShortcut(",")
        Button("Thoát 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Open Settings and bring it to the front. The `SettingsWindowActivator`
    /// also promotes 84Key to a regular app while the window is up — see its doc
    /// comment for why that's required to render correctly.
    private func openSettingsWindow() {
        openSettings()
        SettingsWindowActivator.shared.activate()
    }
}

/// Promotes 84Key to a `.regular` app while the SwiftUI Settings window is open,
/// then reverts to `.accessory` (menu-bar only) when it closes.
///
/// Why: 84Key is an `LSUIElement` accessory app, so it's never the *active* app
/// on its own. AppKit then renders the Settings window's `NavigationSplitView`
/// and native sidebar vibrancy in their inactive/opaque state, which — with
/// macOS wallpaper tinting — looks washed-out and "legacy" (a warm beige panel).
/// Running from Xcode hid the bug because the debugger activates the launched
/// app. Briefly going `.regular` (the same trick `OnboardingController` uses)
/// makes the window render in its normal, active appearance. A Dock icon shows
/// only while Settings is open.
@MainActor
final class SettingsWindowActivator {
    static let shared = SettingsWindowActivator()

    /// Identifier SwiftUI assigns to the window backing the `Settings` scene.
    private static let settingsWindowID = "com_apple_SwiftUI_Settings_window"
    private var closeObserver: NSObjectProtocol?

    private init() {}

    /// Call right after `openSettings()`. Promotes the app, fronts the window,
    /// and arms a one-shot revert for when the user closes Settings.
    func activate() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // The window may not exist on the very first `openSettings()` until the
        // next runloop turn, so look it up (and front it) asynchronously.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let window = NSApp.windows.first(where: {
                      $0.identifier?.rawValue == Self.settingsWindowID
                  })
            else { return }
            window.makeKeyAndOrderFront(nil)
            self.armRevert(for: window)
        }
    }

    /// Revert to a menu-bar-only accessory app once this Settings window closes.
    /// Re-arms on every open (the SwiftUI Settings window is reused, not freed),
    /// removing any prior observer so we never double-register.
    private func armRevert(for window: NSWindow) {
        if let token = closeObserver {
            NotificationCenter.default.removeObserver(token)
            closeObserver = nil
        }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                NSApp.setActivationPolicy(.accessory)
                if let token = self?.closeObserver {
                    NotificationCenter.default.removeObserver(token)
                    self?.closeObserver = nil
                }
            }
        }
    }
}
