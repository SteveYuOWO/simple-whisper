import SwiftUI

struct SettingsGeneralSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        let lang = appState.appLanguage

        SettingsGroupCard {
                HStack {
                    Text(lang.language)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("", selection: $appState.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)
                SettingsSeparator()
                SettingsToggleRow(label: lang.launchAtLogin, isOn: $appState.launchAtLogin)
                SettingsSeparator()
                SettingsToggleRow(label: lang.soundFeedback, isOn: $appState.soundFeedback)
        }
    }
}
