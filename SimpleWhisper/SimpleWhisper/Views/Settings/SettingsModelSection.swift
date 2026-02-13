import SwiftUI

struct SettingsModelSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        let lang = appState.appLanguage

        VStack(spacing: 6) {
            SettingsGroupCard {
                // Model Picker
                HStack {
                    Text(lang.whisperModel)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("", selection: $state.selectedModel) {
                        ForEach(WhisperModel.allCases) { model in
                            Text(model.pickerLabel(lang))
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)

                SettingsSeparator()

                // Model Status Row
                HStack {
                    modelStatusView(lang: lang)
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)
            }

            Text(lang.modelHint)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func modelStatusView(lang: AppLanguage) -> some View {
        if appState.isDownloadingModel {
            // Downloading state
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.downloading)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                    ProgressView(value: appState.modelDownloadProgress)
                        .progressViewStyle(.linear)
                }
                Button(lang.cancel) {
                    appState.cancelModelDownload()
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
            }
        } else if appState.modelDownloadError != nil {
            // Error state
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
                Text(lang.downloadFailed)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                Spacer()
                Button(lang.retry) {
                    appState.downloadSelectedModel()
                }
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
                .tint(Color.brand)
            }
        } else if appState.isModelDownloaded {
            // Downloaded state
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.success)
                    .font(.system(size: 13))
                Text(lang.downloaded)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.success)
                Spacer()
                Button(lang.deleteModel) {
                    appState.deleteSelectedModel()
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
            }
        } else {
            // Not downloaded state
            HStack(spacing: 8) {
                Text(appState.selectedModel.sizeDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button(lang.downloadModel) {
                    appState.downloadSelectedModel()
                }
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
                .tint(Color.brand)
            }
        }
    }
}
