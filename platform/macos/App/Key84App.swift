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
    }
}

private struct MenuContent: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if app.isRunning {
            Button(settings.language == 1 ? "Switch to English" : "Switch to Vietnamese") {
                settings.language = (settings.language == 1) ? 0 : 1
            }
            .keyboardShortcut("e")
        } else {
            Text(app.hasPermission
                 ? "Permission granted — click Restart to activate"
                 : "⚠︎ Accessibility permission needed")
            Button("Open Accessibility Settings…") { app.openAccessibilitySettings() }
            Button("Restart 84Key") { app.relaunch() }
        }

        Divider()
        Button("Settings…") { openSettings() }
            .keyboardShortcut(",")
        Button("Quit 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
