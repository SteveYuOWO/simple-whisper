import SwiftUI

struct SettingsInputSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let lang = appState.appLanguage

        SettingsGroupCard {
            SettingsRowView(
                label: lang.microphone,
                value: appState.selectedMicrophone
            )
            SettingsSeparator()
            HStack {
                Text(lang.hotkey)
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
                    Text(lang.holdToRecord)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(height: DS.settingsRowHeight)
            .padding(.horizontal, DS.settingsHPadding)
        }
    }
}
