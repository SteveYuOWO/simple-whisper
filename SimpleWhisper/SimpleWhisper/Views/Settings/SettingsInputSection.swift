import SwiftUI

struct SettingsInputSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        SettingsGroupCard {
            SettingsRowView(
                label: "Microphone",
                value: appState.selectedMicrophone
            )
            SettingsSeparator()
            HStack {
                Text("Hotkey")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    Text(appState.hotkeyDisplay)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 6))
                    Text("Hold to record")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(height: DS.settingsRowHeight)
            .padding(.horizontal, DS.settingsHPadding)
        }
    }
}
