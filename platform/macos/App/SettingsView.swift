import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Input") {
                Picker("Input method", selection: $settings.inputType) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                    Text("Simple Telex 1").tag(2)
                    Text("Simple Telex 2").tag(3)
                }
                Picker("Code table", selection: $settings.codeTable) {
                    Text("Unicode").tag(0)
                    Text("TCVN3 (ABC)").tag(1)
                    Text("VNI Windows").tag(2)
                    Text("Unicode Compound").tag(3)
                    Text("Vietnamese CP1258").tag(4)
                }
            }

            Section("Smart features") {
                Toggle("Automatic English detection", isOn: $settings.autoDetectEnglish)
                Text("Skip diacritics while typing an English word in Telex, without switching modes.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Fix diacritics in Spotlight", isOn: $settings.fixSpotlight)
                Toggle("Smart switch key (remember language per app)", isOn: $settings.smartSwitchKey)
            }

            Section("Vietnamese typing") {
                Toggle("Spell check", isOn: $settings.checkSpelling)
                Toggle("Modern orthography (oà, uý)", isOn: $settings.modernOrthography)
                Toggle("Free mark placement", isOn: $settings.freeMark)
                Toggle("Quick Telex (cc→ch, gg→gi…)", isOn: $settings.quickTelex)
                Toggle("Restore word if spelling is wrong", isOn: $settings.restoreIfWrongSpelling)
                Toggle("Quick start consonant (f→ph, j→gi, w→qu)", isOn: $settings.quickStartConsonant)
                Toggle("Quick end consonant (g→ng, h→nh, k→ch)", isOn: $settings.quickEndConsonant)
                Toggle("Allow Z / F / W / J as letters", isOn: $settings.allowZFWJ)
                Toggle("Capitalize first letter", isOn: $settings.upperCaseFirstChar)
            }

            Section("Compatibility") {
                Toggle("Use macros (text expansion)", isOn: $settings.useMacro)
                Toggle("Fix browser address-bar autocomplete", isOn: $settings.fixRecommendBrowser)
                Toggle("Turn off Vietnamese in non-English keyboard layouts", isOn: $settings.otherLanguage)
            }

            Section("System") {
                Toggle("Launch 84Key at login", isOn: $settings.runOnStartup)
                LabeledContent("Switch language") {
                    Text("Click the menu bar “VI/EN” item")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 540)
    }
}
