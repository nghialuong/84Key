//
//  SettingsSections.swift
//  84Key
//
//  The detail panes, built from native `Form { Section } .formStyle(.grouped)`
//  so each page renders exactly like a macOS System Settings pane (native group
//  backgrounds, dividers, row heights, controls) and adopts the system look —
//  including Liquid Glass on macOS 26 — automatically.
//
//  Every control binds to the existing `AppSettings.shared` / `AppController`,
//  so persistence and the engine push-through are unchanged.
//

import SwiftUI

// MARK: - Detail router

/// Switches the main content to match the selected sidebar section. The section
/// title becomes the native window/toolbar title.
struct SettingsDetail: View {
    let section: SettingsSection
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController

    var body: some View {
        Group {
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
        .formStyle(.grouped)
        .navigationTitle(section.title)
    }
}

// MARK: - 1. Tổng quan

private struct OverviewPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var app: AppController

    private var isVietnamese: Bool { settings.language == 1 }

    var body: some View {
        Form {
            Section("Trạng thái") {
                LabeledContent {
                    Button(isVietnamese ? "Chuyển sang tiếng Anh" : "Chuyển sang tiếng Việt") {
                        // Mirrors the menu-bar action: toggle the engine language.
                        settings.language = isVietnamese ? 0 : 1
                    }
                } label: {
                    Text("84Key")
                    Text(isVietnamese ? "Tiếng Việt đang bật" : "Tiếng Việt đang tắt")
                }
                LabeledContent("Phím tắt chuyển ngôn ngữ") {
                    Text("⌥ Space").font(Key84DS.Typography.mono).foregroundStyle(.secondary)
                }
            }

            Section("Quyền truy cập") {
                LabeledContent {
                    if app.hasPermission {
                        Label("Đã cấp quyền", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Key84DS.Color.success)
                            .labelStyle(.titleAndIcon)
                    } else {
                        Button("Mở Cài đặt hệ thống") { app.openAccessibilitySettings() }
                    }
                } label: {
                    Text("Quyền Trợ năng")
                    Text("84Key cần quyền này để xử lý phím gõ.")
                }
                if !app.hasPermission {
                    LabeledContent {
                        Button("Khởi động lại") { app.relaunch() }
                    } label: {
                        Text("Đã cấp quyền nhưng chưa nhận?")
                        Text("Khởi động lại 84Key để áp dụng quyền mới.")
                    }
                }
            }

            Section("Cài đặt nhanh") {
                Toggle("Tự động nhận diện tiếng Anh", isOn: $settings.autoDetectEnglish)
                Toggle("Sửa lỗi bỏ dấu trong Spotlight", isOn: $settings.fixSpotlight)
                Toggle("Phím chuyển thông minh", isOn: $settings.smartSwitchKey)
                Toggle("Khởi động 84Key khi đăng nhập", isOn: $settings.runOnStartup)
            }
        }
    }
}

// MARK: - 2. Nhập liệu

private struct InputPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Kiểu gõ", selection: $settings.inputType) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                    Text("Simple Telex 1").tag(2)
                    Text("Simple Telex 2").tag(3)
                }
                Picker("Bảng mã", selection: $settings.codeTable) {
                    Text("Unicode").tag(0)
                    Text("TCVN3 (ABC)").tag(1)
                    Text("VNI Windows").tag(2)
                    Text("Unicode tổ hợp").tag(3)
                    Text("Vietnamese CP1258").tag(4)
                }
            } header: {
                Text("Bộ gõ")
            } footer: {
                Text("Unicode phù hợp với hầu hết ứng dụng hiện đại.")
            }
        }
    }
}

// MARK: - 3. Gõ tiếng Việt

private struct VietnamesePage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Chính tả") {
                Toggle("Kiểm tra chính tả", isOn: $settings.checkSpelling)
                Toggle("Chính tả hiện đại (oà, uý)", isOn: $settings.modernOrthography)
                Toggle("Bỏ dấu tự do", isOn: $settings.freeMark)
                Toggle("Khôi phục từ nếu sai chính tả", isOn: $settings.restoreIfWrongSpelling)
            }

            Section("Telex nhanh") {
                Toggle("Telex nhanh (cc→ch, gg→gi…)", isOn: $settings.quickTelex)
                Toggle("Phụ âm đầu nhanh (f→ph, j→gi, w→qu)", isOn: $settings.quickStartConsonant)
                Toggle("Phụ âm cuối nhanh (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonant)
                Toggle("Cho phép Z / F / W / J là chữ cái", isOn: $settings.allowZFWJ)
                Toggle("Viết hoa chữ cái đầu", isOn: $settings.upperCaseFirstChar)
            }
        }
    }
}

// MARK: - 4. Tính năng thông minh

private struct SmartPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Tự động") {
                Toggle(isOn: $settings.autoDetectEnglish) {
                    Text("Tự động nhận diện tiếng Anh")
                    Text("Bỏ qua việc bỏ dấu khi gõ từ tiếng Anh trong kiểu Telex, không cần chuyển chế độ.")
                }
                Toggle(isOn: $settings.fixSpotlight) {
                    Text("Sửa lỗi bỏ dấu trong Spotlight")
                    Text("Xử lý riêng Spotlight để tránh lỗi mất backspace khi gõ nhanh.")
                }
                Toggle(isOn: $settings.smartSwitchKey) {
                    Text("Phím chuyển thông minh")
                    Text("Ghi nhớ VI/EN theo từng ứng dụng.")
                }
            }
        }
    }
}

// MARK: - 5. Tương thích

private struct CompatibilityPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Ứng dụng") {
                Toggle("Dùng gõ tắt (text expansion)", isOn: $settings.useMacro)
                Toggle(isOn: $settings.fixRecommendBrowser) {
                    Text("Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt")
                    Text("Chỉ bật nếu bạn gặp lỗi gợi ý hoặc ký tự lạ trong thanh địa chỉ.")
                }
                Toggle("Tắt tiếng Việt với bố cục bàn phím không phải tiếng Anh", isOn: $settings.otherLanguage)
            }
        }
    }
}

// MARK: - 6. Hệ thống

private struct SystemPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Khởi động") {
                Toggle("Khởi động 84Key khi đăng nhập", isOn: $settings.runOnStartup)
            }

            Section("Chuyển ngôn ngữ") {
                LabeledContent("Chuyển ngôn ngữ", value: "Bấm vào mục VI/EN trên thanh menu")
                LabeledContent("Phím tắt chuyển nhanh") {
                    Text("⌥ Space").font(Key84DS.Typography.mono).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 7. Phím tắt

private struct ShortcutsPage: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Chuyển VI/EN") {
                    Text("⌥ Space").font(Key84DS.Typography.mono).foregroundStyle(.secondary)
                }
                LabeledContent("Mở Cài đặt") {
                    Text("⌘ ,").font(Key84DS.Typography.mono).foregroundStyle(.secondary)
                }
            } header: {
                Text("Phím tắt hiện tại")
            } footer: {
                Text("Tùy chỉnh phím tắt sẽ được hỗ trợ trong bản sau.")
            }
        }
    }
}

// MARK: - 8. Nâng cao

private struct AdvancedPage: View {
    @ObservedObject var app: AppController

    var body: some View {
        Form {
            Section {
                LabeledContent("Xử lý cục bộ", value: "Bật")
            } header: {
                Text("Quyền riêng tư")
            } footer: {
                Text("84Key xử lý gõ hoàn toàn trên thiết bị, không gửi nội dung bạn gõ ra ngoài.")
            }

            Section("Chẩn đoán") {
                LabeledContent("Phiên bản", value: Key84Bundle.shortVersion)
                LabeledContent {
                    Button("Khởi động lại") { app.relaunch() }
                } label: {
                    Text("Khởi động lại 84Key")
                    Text("Áp dụng lại quyền Trợ năng sau khi cấp quyền.")
                }
            }
        }
    }
}
