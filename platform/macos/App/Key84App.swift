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
                Text(settings.language == 1 ? "VI" : "EN")
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
        Button("Cài đặt…") { openSettings() }
            .keyboardShortcut(",")
        Button("Thoát 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
