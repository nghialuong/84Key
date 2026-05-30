//
//  SettingsSections.swift
//  84Key
//
//  The main-content pages for each Settings section, built from the 84Key design
//  system and wired to the real `AppSettings` / `AppController`. No engine,
//  InputController or settings-persistence behaviour is changed here — every
//  control binds to an existing property.
//
//  Styling is deliberately restrained and native (no decorative row icons, no
//  forced accent), with leading-aligned content like macOS System Settings.
//

import SwiftUI

// MARK: - Page scaffold

/// Standard page chrome: a title + subtitle header above a width-capped,
/// leading-aligned, scrollable content column.
struct SettingsPage<Content: View>: View {
    let section: SettingsSection
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Key84DS.Layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(Key84DS.Typography.pageTitle)
                    Text(section.subtitle)
                        .font(Key84DS.Typography.pageSubtitle)
                        .foregroundStyle(Key84DS.Color.textSecondary)
                }
                .padding(.bottom, 8)
                content
            }
            .frame(maxWidth: Key84DS.Layout.contentMaxWidth, alignment: .leading)
            .padding(.top, Key84DS.Layout.detailTopPadding)
            .padding(.horizontal, Key84DS.Layout.detailHorizontalPadding)
            .padding(.bottom, Key84DS.Layout.detailBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private var isVietnamese: Bool { settings.language == 1 }

    var body: some View {
        SettingsPage(section: .overview) {
            Key84SettingsGroup("Trạng thái") {
                Key84SettingRow("84Key", subtitle: isVietnamese ? "Tiếng Việt đang bật" : "Tiếng Việt đang tắt") {
                    Button(isVietnamese ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt") {
                        // Mirrors the menu-bar action: toggle the engine language.
                        settings.language = isVietnamese ? 0 : 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                Key84InfoRow("Phím tắt chuyển ngôn ngữ", value: "⌥ Space", monospaced: true)
            }

            PermissionGroup(app: app)

            Key84SettingsGroup("Cài đặt nhanh") {
                Key84ToggleRow("Tự động nhận diện tiếng Anh", isOn: $settings.autoDetectEnglish)
                Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight", isOn: $settings.fixSpotlight)
                Key84ToggleRow("Phím chuyển thông minh", isOn: $settings.smartSwitchKey)
                Key84ToggleRow("Khởi động 84Key khi đăng nhập", isOn: $settings.runOnStartup)
            }
        }
    }
}

/// Accessibility-permission status as a native group row, wired to the real
/// `AppController` flow. Small green status text when granted; a bordered CTA
/// when not.
private struct PermissionGroup: View {
    @ObservedObject var app: AppController

    var body: some View {
        Key84SettingsGroup("Quyền truy cập") {
            Key84SettingRow("Quyền Trợ năng",
                            subtitle: "84Key cần quyền này để xử lý phím gõ.") {
                if app.hasPermission {
                    Label("Đã cấp quyền", systemImage: "checkmark.circle.fill")
                        .font(Key84DS.Typography.rowSubtitle)
                        .foregroundStyle(Key84DS.Color.success)
                } else {
                    Button("Mở Cài đặt hệ thống") { app.openAccessibilitySettings() }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                }
            }
            if !app.hasPermission {
                Key84SettingRow("Đã cấp quyền nhưng chưa nhận?",
                                subtitle: "Khởi động lại 84Key để áp dụng quyền mới.") {
                    Button("Khởi động lại") { app.relaunch() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
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
                Key84PickerRow("Kiểu gõ", selection: $settings.inputType) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                    Text("Simple Telex 1").tag(2)
                    Text("Simple Telex 2").tag(3)
                }
                Key84PickerRow("Bảng mã", selection: $settings.codeTable) {
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
                               isOn: $settings.autoDetectEnglish)
                Key84ToggleRow("Sửa lỗi bỏ dấu trong Spotlight",
                               subtitle: "Xử lý riêng Spotlight để tránh lỗi mất backspace khi gõ nhanh.",
                               isOn: $settings.fixSpotlight)
                Key84ToggleRow("Phím chuyển thông minh",
                               subtitle: "Ghi nhớ VI/EN theo từng ứng dụng.",
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
                Key84ToggleRow("Khởi động 84Key khi đăng nhập", isOn: $settings.runOnStartup)
            }

            Key84SettingsGroup("Chuyển ngôn ngữ") {
                Key84InfoRow("Chuyển ngôn ngữ", value: "Bấm vào mục VI/EN trên thanh menu")
                Key84InfoRow("Phím tắt chuyển nhanh", value: "⌥ Space", monospaced: true)
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
                Key84InfoRow("Chuyển VI/EN", value: "⌥ Space", monospaced: true)
                Key84InfoRow("Mở Cài đặt", value: "⌘ ,", monospaced: true)
            }
        }
    }
}

// MARK: - 8. Nâng cao

private struct AdvancedPage: View {
    @ObservedObject var app: AppController

    var body: some View {
        SettingsPage(section: .advanced) {
            Key84SettingsGroup("Quyền riêng tư",
                               footer: "84Key xử lý gõ hoàn toàn trên thiết bị, không gửi nội dung bạn gõ ra ngoài.") {
                Key84InfoRow("Xử lý cục bộ", value: "Bật")
            }

            Key84SettingsGroup("Chẩn đoán") {
                Key84InfoRow("Phiên bản", value: Key84Bundle.shortVersion)
                Key84SettingRow("Khởi động lại 84Key",
                                subtitle: "Áp dụng lại quyền Trợ năng sau khi cấp quyền.") {
                    Button("Khởi động lại") { app.relaunch() }
                        .controlSize(.small)
                }
            }
        }
    }
}
