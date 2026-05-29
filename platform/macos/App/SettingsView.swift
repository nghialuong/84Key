import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Nhập liệu") {
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
            }

            Section("Tính năng thông minh") {
                Toggle("Tự động nhận diện tiếng Anh", isOn: $settings.autoDetectEnglish)
                Text("Bỏ qua việc bỏ dấu khi gõ một từ tiếng Anh trong kiểu Telex, không cần chuyển chế độ.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Sửa lỗi bỏ dấu trong Spotlight", isOn: $settings.fixSpotlight)
                Toggle("Phím chuyển thông minh (nhớ ngôn ngữ theo từng ứng dụng)", isOn: $settings.smartSwitchKey)
            }

            Section("Gõ tiếng Việt") {
                Toggle("Kiểm tra chính tả", isOn: $settings.checkSpelling)
                Toggle("Chính tả hiện đại (oà, uý)", isOn: $settings.modernOrthography)
                Toggle("Bỏ dấu tự do", isOn: $settings.freeMark)
                Toggle("Telex nhanh (cc→ch, gg→gi…)", isOn: $settings.quickTelex)
                Toggle("Khôi phục từ nếu sai chính tả", isOn: $settings.restoreIfWrongSpelling)
                Toggle("Phụ âm đầu nhanh (f→ph, j→gi, w→qu)", isOn: $settings.quickStartConsonant)
                Toggle("Phụ âm cuối nhanh (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonant)
                Toggle("Cho phép Z / F / W / J là chữ cái", isOn: $settings.allowZFWJ)
                Toggle("Viết hoa chữ cái đầu", isOn: $settings.upperCaseFirstChar)
            }

            Section("Tương thích") {
                Toggle("Dùng gõ tắt (text expansion)", isOn: $settings.useMacro)
                Toggle("Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt", isOn: $settings.fixRecommendBrowser)
                Toggle("Tắt tiếng Việt với bố cục bàn phím không phải tiếng Anh", isOn: $settings.otherLanguage)
            }

            Section("Hệ thống") {
                Toggle("Khởi động 84Key khi đăng nhập", isOn: $settings.runOnStartup)
                LabeledContent("Chuyển ngôn ngữ") {
                    Text("Bấm vào mục “VI/EN” trên thanh menu")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 540)
    }
}
