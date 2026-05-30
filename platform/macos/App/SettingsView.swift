import SwiftUI

/// The 84Key Settings window: a native macOS Settings-style two-column layout
/// (translucent sidebar + width-capped, scrollable detail) built on the Key84
/// design system. All controls bind directly to `AppSettings.shared`, so
/// persistence and the engine push-through are unchanged.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var app = AppController.shared
    @State private var selection: SettingsSection = .overview

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(
                    min: Key84DS.Layout.sidebarMinWidth,
                    ideal: Key84DS.Layout.sidebarWidth,
                    max: Key84DS.Layout.sidebarMaxWidth
                )
        } detail: {
            SettingsDetail(section: selection, settings: settings, app: app)
        }
        .navigationSplitViewStyle(.balanced)
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
