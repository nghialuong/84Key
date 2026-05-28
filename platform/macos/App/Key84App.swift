import SwiftUI

@main
struct Key84App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            // VI/EN indicator; a full toggle lands with the input controller (T8).
            Text("VI")
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("84Key — Vietnamese input")
        Divider()
        Button("Settings…") { openSettings() }
        Button("Quit 84Key") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
