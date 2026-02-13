import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: SettingsTab

    var body: some View {
        let lang = appState.appLanguage

        HStack(spacing: 0) {
            // MARK: - Sidebar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brand)
                    Text("Simple Whisper")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)

                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .frame(width: 16)
                            Text(tab.title(lang))
                                .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.textPrimary : Color.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(
                            selectedTab == tab ? Color.bgTertiary : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(EdgeInsets(top: 48, leading: 12, bottom: 20, trailing: 12))
            .frame(width: DS.settingsSidebarWidth)
            .frame(maxHeight: .infinity)
            .background(Color.bgSecondary)

            // MARK: - Content
            VStack(alignment: .leading, spacing: 14) {
                Text(selectedTab.title(lang))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                switch selectedTab {
                case .general:
                    SettingsGeneralSection()
                case .model:
                    SettingsModelSection()
                case .input:
                    SettingsInputSection()
                case .ai:
                    SettingsAISection()
                case .history:
                    SettingsHistorySection()
                }

                Spacer()
            }
            .padding(EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: DS.settingsMinWidth, minHeight: DS.settingsMinHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
