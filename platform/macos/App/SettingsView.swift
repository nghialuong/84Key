import SwiftUI

/// The 84Key Settings window: a native macOS Settings-style two-column layout —
/// a quiet translucent sidebar and a leading-aligned, width-capped, scrollable
/// detail pane — built on the Key84 design system. All controls bind directly
/// to `AppSettings.shared`, so persistence and the engine push-through are
/// unchanged.
///
/// A plain `HStack` (rather than `NavigationSplitView`) is used on purpose: it
/// keeps the detail content pinned to the leading edge instead of floating in
/// centered whitespace, and avoids a duplicate section title in the title bar.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var app = AppController.shared
    @State private var selection: SettingsSection = .overview

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
                .frame(width: Key84DS.Layout.sidebarWidth)

            Divider()

            SettingsDetail(section: selection, settings: settings, app: app)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: Key84DS.Layout.windowMinWidth,
            idealWidth: Key84DS.Layout.windowIdealWidth,
            maxWidth: .infinity,
            minHeight: Key84DS.Layout.windowMinHeight,
            idealHeight: Key84DS.Layout.windowIdealHeight,
            maxHeight: .infinity
        )
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
}
#endif
