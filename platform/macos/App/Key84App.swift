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

    var body: some View {
        if app.isRunning {
            Button(settings.language == 1 ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt") {
                settings.language = (settings.language == 1) ? 0 : 1
            }
            .keyboardShortcut("e")
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
