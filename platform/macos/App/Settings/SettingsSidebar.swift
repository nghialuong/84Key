//
//  SettingsSidebar.swift
//  84Key
//
//  Native macOS Settings-style sidebar: a translucent column of accent-selected
//  destinations with an app-identity footer.
//

import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Key84DS.Spacing.xxs) {
                    ForEach(SettingsSection.allCases) { section in
                        Key84SidebarItem(
                            section.sidebarModel,
                            isSelected: selection == section
                        ) {
                            selection = section
                        }
                    }
                }
                .padding(.horizontal, Key84DS.Spacing.sm)
                .padding(.top, Key84DS.Spacing.sm)
            }

            Divider()
            Key84SidebarFooter(version: Key84Bundle.shortVersion)
        }
        .frame(maxHeight: .infinity)
        .key84SidebarMaterial()
    }
}

#if DEBUG
#Preview("Sidebar") {
    @Previewable @State var selection: SettingsSection = .overview
    SettingsSidebar(selection: $selection)
        .frame(width: Key84DS.Layout.sidebarWidth, height: 560)
}
#endif
