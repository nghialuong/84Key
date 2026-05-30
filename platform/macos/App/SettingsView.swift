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
        .frame(
            minWidth: Key84DS.Layout.windowMinWidth,
            idealWidth: Key84DS.Layout.windowIdealWidth,
            minHeight: Key84DS.Layout.windowMinHeight,
            idealHeight: Key84DS.Layout.windowIdealHeight
        )
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
}
#endif
