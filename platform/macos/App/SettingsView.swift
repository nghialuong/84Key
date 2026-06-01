import SwiftUI

/// The 84Key Settings window: a native macOS Settings layout built on
/// `NavigationSplitView` + a `List(selection:)` sidebar (so macOS draws the real
/// selected-row state) and a leading-aligned, width-capped detail pane. All
/// controls bind to `AppSettings.shared`, so persistence and the engine
/// push-through are unchanged.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var app = AppController.shared
    @State private var selection: SettingsSection? = .overview

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: Key84DS.Layout.sidebarMinWidth,
                    ideal: Key84DS.Layout.sidebarIdealWidth,
                    max: Key84DS.Layout.sidebarMaxWidth
                )
        } detail: {
            SettingsDetail(section: selection ?? .overview, settings: settings, app: app)
        }
        // Fixed window size: only the sidebar divider is draggable, the window
        // itself can't be resized (see `.windowResizability(.contentSize)`).
        .frame(
            width: Key84DS.Layout.windowWidth,
            height: Key84DS.Layout.windowHeight
        )
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
}
#endif
