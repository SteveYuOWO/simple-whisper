import SwiftUI

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(Color.brand)
                .labelsHidden()
        }
        .frame(height: DS.settingsRowHeight)
        .padding(.horizontal, DS.settingsHPadding)
    }
}
