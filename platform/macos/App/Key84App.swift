import SwiftUI

@main
struct Key84App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings)
        } label: {
            // VI/EN indicator; clicking the toggle below switches language.
            Text(settings.language == 1 ? "VI" : "EN")
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(settings.language == 1 ? "Switch to English" : "Switch to Vietnamese") {
            settings.language = (settings.language == 1) ? 0 : 1
        }
        .keyboardShortcut("e")

        Divider()
        Button("Settings…") { openSettings() }
            .keyboardShortcut(",")
        Button("Quit 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
