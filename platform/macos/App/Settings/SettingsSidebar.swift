//
//  SettingsSidebar.swift
//  84Key
//
//  Native macOS Settings-style sidebar: a quiet, translucent column of
//  destinations with a neutral selection highlight and a small app-identity
//  footer.
//

import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        Key84SidebarItem(
                            section.sidebarModel,
                            isSelected: selection == section
                        ) {
                            selection = section
                        }
                    }
                }
                .padding(.horizontal, Key84DS.Layout.sidebarRowInset)
                .padding(.top, Key84DS.Spacing.md)
            }

            Divider()
            Key84SidebarFooter(version: Key84Bundle.shortVersion)
        }
        .frame(maxHeight: .infinity)
        .key84SidebarSurface()
    }
}

#if DEBUG
#Preview("Sidebar") {
    @Previewable @State var selection: SettingsSection = .overview
    SettingsSidebar(selection: $selection)
        .frame(width: Key84DS.Layout.sidebarWidth, height: 560)
}
#endif
