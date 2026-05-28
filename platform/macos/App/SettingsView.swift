import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("84Key Settings")
                .font(.title2)
            Text("Input method, code table, English auto-detection, the Spotlight "
                 + "fix and other options will appear here.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 300, alignment: .topLeading)
    }
}
