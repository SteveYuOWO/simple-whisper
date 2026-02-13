import SwiftUI

struct SettingsGeneralSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        SettingsGroupCard {
                SettingsToggleRow(label: "Launch at Login", isOn: $appState.launchAtLogin)
                SettingsSeparator()
                SettingsToggleRow(label: "Sound Feedback", isOn: $appState.soundFeedback)
                SettingsSeparator()
                SettingsToggleRow(label: "Auto Punctuation", isOn: $appState.autoPunctuation)
                SettingsSeparator()
                SettingsToggleRow(label: "Show in Dock", isOn: $appState.showInDock)
        }
    }
}
