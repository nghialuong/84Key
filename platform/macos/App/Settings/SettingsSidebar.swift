//
//  SettingsSidebar.swift
//  84Key
//
//  Native macOS Settings sidebar: a `List(selection:)` with `.listStyle(.sidebar)`
//  inside a `NavigationSplitView`. That combination is what System Settings uses,
//  so macOS itself renders the translucent sidebar material (real behind-window
//  vibrancy, Liquid Glass on macOS 26) and the rounded, inset selection row. We
//  deliberately add NO background of our own — any custom material/color here only
//  fights the system one and produces the flat off-white "custom" look. The only
//  brand touch is `.tint`, which recolors the native selection highlight pink
//  (white text/icon on top, handled by the system). The app-identity footer is
//  attached via `safeAreaInset` so the List stays the full-height native sidebar.
//

import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)                     // native translucent sidebar material
        .tint(Key84DS.Color.accent)              // brand pink on the native selection row
        .toolbar(removing: .sidebarToggle)       // drop the stray centered toggle button
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarIdentityFooter()
        }
    }
}

/// Quiet identity at the bottom of the sidebar: tiny badge, name, version.
private struct SidebarIdentityFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Key84AppBadge(size: 18)
                Text("84Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Key84DS.Color.textPrimary)
                Text("·").foregroundStyle(.tertiary)
                Text(Key84Bundle.shortVersion)
                    .font(Key84DS.Typography.caption)
                    .foregroundStyle(Key84DS.Color.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

#if DEBUG
#Preview("Sidebar") {
    @Previewable @State var selection: SettingsSection? = .overview
    SettingsSidebar(selection: $selection)
        .frame(width: 240, height: 560)
}
#endif
