//
//  SettingsSections.swift
//  84Key
//
//  The main-content pages for each Settings section, built from the 84Key design
//  system and wired to the real `AppSettings` / `AppController`. No engine,
//  InputController or settings-persistence behaviour is changed here — every
//  control binds to an existing `AppSettings` property.
//

import SwiftUI

// MARK: - Page scaffold

/// Standard page chrome: a title + subtitle header above a width-capped,
/// scrollable content column. Keeps every section visually consistent and
/// prevents rows from stretching too wide on large windows.
struct SettingsPage<Content: View>: View {
    let section: SettingsSection
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Key84DS.Layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: Key84DS.Spacing.xs) {
                    Text(section.title)
                        .font(Key84DS.Typography.largeTitle)
                    Text(section.subtitle)
                        .font(Key84DS.Typography.rowSubtitle)
                        .foregroundStyle(Key84DS.Color.textSecondary)
                }
                content
            }
            .frame(maxWidth: Key84DS.Layout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, Key84DS.Spacing.xxl)
            .padding(.vertical, Key84DS.Spacing.xl)
        }
        .navigationTitle(section.title)
    }
}

// MARK: - Detail router

/// Switches the main content to match the selected sidebar section.
struct SettingsDetail: View {
    let section: SettingsSection
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController

    var body: some View {
        switch section {
        case .overview:      OverviewPage(settings: settings, app: app)
        case .input:         InputPage(settings: settings)
        case .vietnamese:    VietnamesePage(settings: settings)
        case .smart:         SmartPage(settings: settings)
        case .compatibility: CompatibilityPage(settings: settings)
        case .system:        SystemPage(settings: settings)
        case .shortcuts:     ShortcutsPage()
        case .advanced:      AdvancedPage(app: app)
        }
    }
}

// MARK: - 1. Tổng quan

private struct OverviewPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController

    var body: some View {
        SettingsPage(section: .overview) {
            Key84HeroStatusCard(
                isVietnamese: settings.language == 1,
                shortcut: "⌘E",
                primaryActionTitle: settings.language == 1 ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt"
            ) {
                // Mirrors the menu-bar action: toggle the engine language.
                settings.language = (settings.language == 1) ? 0 : 1
            }

            PermissionCard(app: app)

            Key84SettingsGroup("Cài đặt nhanh") {
                Key84ToggleRow("Tự động nhận diện tiếng Anh",
                               systemIcon: "character.cursor.ibeam",
                               isOn: $settings.autoDetectEnglish)
                Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight",
                               systemIcon: "magnifyingglass",
                               isOn: $settings.fixSpotlight)
                Key84ToggleRow("Phím chuyển thông minh",
                               systemIcon: "rectangle.2.swap",
                               isOn: $settings.smartSwitchKey)
                Key84ToggleRow("Khởi động 84Key khi đăng nhập",
                               systemIcon: "power",
                               isOn: $settings.runOnStartup)
            }
        }
    }
}

/// Accessibility-permission status, wired to the real `AppController` flow.
private struct PermissionCard: View {
    @ObservedObject var app: AppController

    var body: some View {
        Key84GlassCard {
            HStack(alignment: .top, spacing: Key84DS.Spacing.md) {
                Image(systemName: app.hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: Key84DS.Layout.iconHero))
                    .foregroundStyle(app.hasPermission ? Key84DS.Color.success : Key84DS.Color.warning)

                VStack(alignment: .leading, spacing: Key84DS.Spacing.sm) {
                    Text("Quyền Trợ năng (Accessibility)")
                        .font(Key84DS.Typography.rowTitle.weight(.semibold))

                    if app.hasPermission {
                        Key84StatusChip("Đã cấp quyền",
                                        systemIcon: "checkmark.circle.fill",
                                        style: .success)
                    } else {
                        Text("84Key cần quyền Trợ năng để nhận phím và đặt dấu tiếng Việt. Nội dung bạn gõ không được gửi ra ngoài.")
                            .font(Key84DS.Typography.rowSubtitle)
                            .foregroundStyle(Key84DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Key84DS.Spacing.sm) {
                            Button("Mở Cài đặt hệ thống") { app.openAccessibilitySettings() }
                                .buttonStyle(.borderedProminent)
                                .tint(Key84DS.Color.accent)
                            Button("Khởi động lại 84Key") { app.relaunch() }
                        }
                        .padding(.top, Key84DS.Spacing.xxs)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 2. Nhập liệu

private struct InputPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(section: .input) {
            Key84SettingsGroup("Bộ gõ", footer: "Unicode phù hợp với hầu hết ứng dụng hiện đại.") {
                Key84PickerRow("Kiểu gõ", systemIcon: "keyboard", selection: $settings.inputType) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                    Text("Simple Telex 1").tag(2)
                    Text("Simple Telex 2").tag(3)
                }
                Key84PickerRow("Bảng mã", systemIcon: "textformat", selection: $settings.codeTable) {
                    Text("Unicode").tag(0)
                    Text("TCVN3 (ABC)").tag(1)
                    Text("VNI Windows").tag(2)
                    Text("Unicode tổ hợp").tag(3)
                    Text("Vietnamese CP1258").tag(4)
                }
            }
        }
    }
}

// MARK: - 3. Gõ tiếng Việt

private struct VietnamesePage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(section: .vietnamese) {
            Key84SettingsGroup("Chính tả") {
                Key84ToggleRow("Kiểm tra chính tả", isOn: $settings.checkSpelling)
                Key84ToggleRow("Chính tả hiện đại (oà, uý)", isOn: $settings.modernOrthography)
                Key84ToggleRow("Bỏ dấu tự do", isOn: $settings.freeMark)
                Key84ToggleRow("Khôi phục từ nếu sai chính tả", isOn: $settings.restoreIfWrongSpelling)
            }

            Key84SettingsGroup("Telex nhanh") {
                Key84ToggleRow("Telex nhanh (cc→ch, gg→gi…)", isOn: $settings.quickTelex)
                Key84ToggleRow("Phụ âm đầu nhanh (f→ph, j→gi, w→qu)", isOn: $settings.quickStartConsonant)
                Key84ToggleRow("Phụ âm cuối nhanh (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonant)
                Key84ToggleRow("Cho phép Z / F / W / J là chữ cái", isOn: $settings.allowZFWJ)
                Key84ToggleRow("Viết hoa chữ cái đầu", isOn: $settings.upperCaseFirstChar)
            }
        }
    }
}

// MARK: - 4. Tính năng thông minh

private struct SmartPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(section: .smart) {
            Key84SettingsGroup("Tự động") {
                Key84ToggleRow("Tự động nhận diện tiếng Anh",
                               subtitle: "Bỏ qua việc bỏ dấu khi gõ từ tiếng Anh trong kiểu Telex, không cần chuyển chế độ.",
                               systemIcon: "character.cursor.ibeam",
                               isOn: $settings.autoDetectEnglish)
                Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight",
                               subtitle: "Xử lý riêng Spotlight để tránh lỗi mất backspace khi gõ nhanh.",
                               systemIcon: "magnifyingglass",
                               isOn: $settings.fixSpotlight)
                Key84ToggleRow("Phím chuyển thông minh",
                               subtitle: "Ghi nhớ VI/EN theo từng ứng dụng.",
                               systemIcon: "rectangle.2.swap",
                               isOn: $settings.smartSwitchKey)
            }
        }
    }
}

// MARK: - 5. Tương thích

private struct CompatibilityPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(section: .compatibility) {
            Key84SettingsGroup("Ứng dụng") {
                Key84ToggleRow("Dùng gõ tắt (text expansion)", isOn: $settings.useMacro)
                Key84ToggleRow("Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt",
                               subtitle: "Chỉ bật nếu bạn gặp lỗi gợi ý hoặc ký tự lạ trong thanh địa chỉ.",
                               isOn: $settings.fixRecommendBrowser)
                Key84ToggleRow("Tắt tiếng Việt với bố cục bàn phím không phải tiếng Anh",
                               isOn: $settings.otherLanguage)
            }
        }
    }
}

// MARK: - 6. Hệ thống

private struct SystemPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(section: .system) {
            Key84SettingsGroup("Khởi động") {
                Key84ToggleRow("Khởi động 84Key khi đăng nhập",
                               systemIcon: "power",
                               isOn: $settings.runOnStartup)
            }

            Key84SettingsGroup("Chuyển ngôn ngữ") {
                Key84InfoRow("Chuyển ngôn ngữ",
                             systemIcon: "globe",
                             value: "Bấm vào mục VI/EN trên thanh menu")
                Key84InfoRow("Phím tắt chuyển nhanh",
                             systemIcon: "command",
                             value: "⌘E")
            }
        }
    }
}

// MARK: - 7. Phím tắt

private struct ShortcutsPage: View {
    var body: some View {
        SettingsPage(section: .shortcuts) {
            Key84SettingsGroup("Phím tắt hiện tại",
                               footer: "Tùy chỉnh phím tắt sẽ được hỗ trợ trong bản sau.") {
                Key84InfoRow("Chuyển VI/EN", systemIcon: "globe", value: "⌘E")
                Key84InfoRow("Mở Cài đặt", systemIcon: "gearshape", value: "⌘,")
            }
        }
    }
}

// MARK: - 8. Nâng cao

private struct AdvancedPage: View {
    @ObservedObject var app: AppController

    var body: some View {
        SettingsPage(section: .advanced) {
            Key84GlassCard {
                HStack(alignment: .top, spacing: Key84DS.Spacing.md) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: Key84DS.Layout.iconHero))
                        .foregroundStyle(Key84DS.Color.accent)
                    VStack(alignment: .leading, spacing: Key84DS.Spacing.xs) {
                        Text("Riêng tư theo mặc định")
                            .font(Key84DS.Typography.rowTitle.weight(.semibold))
                        Text("84Key xử lý gõ hoàn toàn trên thiết bị, không gửi nội dung bạn gõ ra ngoài.")
                            .font(Key84DS.Typography.rowSubtitle)
                            .foregroundStyle(Key84DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }

            Key84SettingsGroup("Chẩn đoán") {
                Key84InfoRow("Phiên bản", systemIcon: "info.circle", value: Key84Bundle.shortVersion)
                Key84SettingRow("Khởi động lại 84Key",
                                subtitle: "Áp dụng lại quyền Trợ năng sau khi cấp quyền.",
                                systemIcon: "arrow.clockwise") {
                    Button("Khởi động lại") { app.relaunch() }
                }
            }
        }
    }
}
