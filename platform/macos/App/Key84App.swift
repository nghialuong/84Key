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

    /// Open Settings and bring it to the front. As a menu-bar accessory app,
    /// 84Key isn't auto-activated, so `openSettings()` alone can leave the window
    /// buried behind other apps' windows. We activate and front it *once*; the
    /// window level is left untouched, so the user can still send it behind other
    /// windows afterward.
    private func openSettingsWindow() {
        openSettings()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }?
                .makeKeyAndOrderFront(nil)
        }
    }
}
