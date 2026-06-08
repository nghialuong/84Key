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

/// Switches the main content to match the selected sidebar section. The page
/// title is rendered as a large, leading-aligned header above the grouped form
/// (`DetailTitleHeader`) rather than the small toolbar title, so it reads big and
/// lines up with the form's content inset — like a macOS large-title pane.
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
            case .shortcuts:     ShortcutsPage(settings: settings)
            case .advanced:      AdvancedPage(app: app)
            case .about:         AboutPage()
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailTitleHeader(title: section.title)
        }
        // Keep a window/proxy title without showing the small toolbar duplicate.
        .navigationTitle("")
    }
}

/// Large, leading-aligned page title that sits above the grouped form. Its
/// horizontal inset matches the grouped `Form` content margin so the title lines
/// up with the section headers and rows below it.
private struct DetailTitleHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Key84DS.Layout.detailTitleLeading)
        .padding(.top, 18)
        .padding(.bottom, 6)
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
                    Text(Key84Shortcut.displayString(settings.switchKey))
                        .font(Key84DS.Typography.mono).foregroundStyle(.secondary)
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
                    ShortcutRecorderField(value: $settings.switchKey)
                }
            }
        }
    }
}

// MARK: - 7. Phím tắt

private struct ShortcutsPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                LabeledContent("Chuyển VI/EN") {
                    ShortcutRecorderField(value: $settings.switchKey)
                }
                LabeledContent("Mở Cài đặt") {
                    Text("⌘ ,").font(Key84DS.Typography.mono).foregroundStyle(.secondary)
                }
            } header: {
                Text("Phím tắt hiện tại")
            } footer: {
                Text("Bấm vào ô phím tắt rồi nhấn tổ hợp mới: một phím kèm ⌘/⌥/⌃/⇧, hoặc từ 2 phím ⌘/⌥/⌃/⇧ trở lên (vd ⇧⌘). Phím chuyển VI/EN áp dụng toàn hệ thống.")
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

// MARK: - 9. Giới thiệu

private struct AboutPage: View {
    private let repoURL    = URL(string: "https://github.com/nghialuong/84Key")!
    private let authorURL  = URL(string: "https://github.com/nghialuong")!
    private let openKeyURL = URL(string: "https://github.com/tuyenvm/OpenKey")!
    private let wordsURL   = URL(string: "https://github.com/first20hours/google-10000-english")!

    var body: some View {
        Form {
            // Hero: centered logo, app name, version (no grouped card).
            VStack(spacing: 6) {
                Key84AppIcon(size: 72)
                Text("84Key")
                    .font(.title.weight(.bold))
                Text("Phiên bản \(Key84Bundle.shortVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)

            Section("Liên kết") {
                LabeledContent("Mã nguồn") {
                    Link("github.com/nghialuong/84Key", destination: repoURL)
                }
                LabeledContent("Tác giả") {
                    Link("nghialuong", destination: authorURL)
                }
            }

            Section {
                LabeledContent("OpenKey") {
                    Link("Mai Vũ Tuyên", destination: openKeyURL)
                }
                LabeledContent("google-10000-english") {
                    Link("first20hours", destination: wordsURL)
                }
            } header: {
                Text("Nguồn mở")
            } footer: {
                Text("Engine gõ tiếng Việt dựa trên OpenKey của Mai Vũ Tuyên (GPLv3). "
                   + "Danh sách từ tiếng Anh từ google-10000-english (public domain / MIT). "
                   + "84Key được phát hành theo giấy phép GPLv3.")
            }

            // Closing line, centered, with a brand-pink heart.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                (Text("Phát triển bởi nghialuong với tất cả trái tim ")
                 + Text(Image(systemName: "heart.fill")).foregroundColor(Key84DS.Color.accent))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .listRowBackground(Color.clear)
        }
    }
}
