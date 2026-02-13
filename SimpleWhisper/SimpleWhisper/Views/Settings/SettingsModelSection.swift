import SwiftUI

struct SettingsModelSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let lang = appState.appLanguage

        VStack(spacing: 6) {
            SettingsGroupCard {
                SettingsRowView(
                    label: lang.whisperModel,
                    value: "\(appState.selectedModel.rawValue) (\(appState.selectedModel.sizeDescription))"
                )
                SettingsSeparator()
                SettingsRowView(
                    label: lang.language,
                    value: appState.selectedLanguage.displayName(lang)
                )
            }

            Text(lang.modelHint)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
