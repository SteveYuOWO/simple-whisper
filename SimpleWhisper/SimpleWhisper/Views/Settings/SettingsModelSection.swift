import SwiftUI

struct SettingsModelSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 6) {
            SettingsGroupCard {
                SettingsRowView(
                    label: "Whisper Model",
                    value: "\(appState.selectedModel.rawValue) (\(appState.selectedModel.sizeDescription))"
                )
                SettingsSeparator()
                SettingsRowView(
                    label: "Language",
                    value: appState.selectedLanguage.rawValue
                )
            }

            Text("Smaller models are faster but less accurate. Larger models require more memory.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
