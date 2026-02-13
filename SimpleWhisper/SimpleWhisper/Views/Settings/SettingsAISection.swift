import SwiftUI

struct SettingsAISection: View {
    @Environment(AppState.self) private var appState
    @State private var isTesting = false

    var body: some View {
        @Bindable var appState = appState
        let lang = appState.appLanguage

        VStack(spacing: DS.settingsSectionGap) {
            // Enable toggle + Test Connection
            SettingsGroupCard {
                VStack(spacing: 0) {
                    HStack {
                        Text(lang.enableAIEnhancement)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if !appState.isLLMConfigured && appState.enableLLMEnhancement {
                            Text(lang.configureAPIFirst)
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                        Toggle("", isOn: $appState.enableLLMEnhancement)
                            .toggleStyle(.switch)
                            .tint(Color.brand)
                            .labelsHidden()
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)

                    SettingsSeparator()

                    HStack {
                        Button(action: testConnection) {
                            HStack(spacing: 6) {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(lang.testing)
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 12))
                                    Text(lang.testConnection)
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand)
                        .disabled(isTesting)

                        Spacer()
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
                }
            }

            // Ollama-specific UI
            if appState.llmProvider == .ollama {
                ollamaSection
            }
        }
    }


    @ViewBuilder
    private var ollamaSection: some View {
        let lang = appState.appLanguage

        SettingsGroupCard {
            VStack(spacing: 0) {
                // Installation status
                HStack {
                    Text(appState.isOllamaInstalled ? lang.ollamaInstalled : lang.ollamaNotInstalled)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()

                    if !appState.isOllamaInstalled {
                        Button(lang.installOllama) {
                            if let url = URL(string: "https://ollama.ai") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand)
                        .controlSize(.small)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.isOllamaRunning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(appState.isOllamaRunning ? lang.ollamaRunning : lang.ollamaNotRunning)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)

                // Start Ollama button (if installed but not running)
                if appState.isOllamaInstalled && !appState.isOllamaRunning {
                    SettingsSeparator()

                    HStack {
                        Spacer()
                        Button(action: {
                            Task {
                                await appState.startOllamaService()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if appState.isStartingOllama {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(appState.isStartingOllama ? lang.startingOllama : lang.startOllama)
                            }
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand)
                        .disabled(appState.isStartingOllama)
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
                }

                // Installed models list
                if appState.isOllamaRunning && !appState.installedOllamaModels.isEmpty {
                    SettingsSeparator()

                    HStack {
                        Text(lang.model)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Picker("", selection: Bindable(appState).llmModel) {
                            ForEach(appState.installedOllamaModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
                }
            }
        }

        // Download model section
        if appState.isOllamaRunning {
            SettingsGroupCard {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.recommendedModels)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(lang.localModelHint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DS.settingsHPadding)
                    .padding(.vertical, 12)

                    SettingsSeparator()

                    // Recommended models list
                    ForEach(Array(OllamaManager.recommendedModels.enumerated()), id: \.offset) { index, model in
                        if index > 0 {
                            SettingsSeparator()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(model.size)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if appState.installedOllamaModels.contains(model.name) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                        Text(lang.downloaded)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                    }
                                    Button {
                                        Task {
                                            await appState.deleteOllamaModel(model.name)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.secondary)
                                }
                            } else if appState.isDownloadingOllamaModel && appState.downloadingOllamaModelName == model.name {
                                HStack(spacing: 8) {
                                    ProgressView(value: appState.ollamaModelDownloadProgress)
                                        .frame(width: 80)
                                        .tint(Color.brand)
                                    Text("\(Int(appState.ollamaModelDownloadProgress * 100))%")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .frame(width: 36, alignment: .trailing)
                                }
                            } else {
                                Button {
                                    Task {
                                        await appState.downloadOllamaModel(model.name)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 11))
                                        Text(lang.downloadModel)
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.brand)
                                .controlSize(.small)
                                .disabled(appState.isDownloadingOllamaModel)
                            }
                        }
                        .frame(height: DS.settingsRowHeight)
                        .padding(.horizontal, DS.settingsHPadding)
                    }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true

        let provider = appState.llmProvider
        let apiKey = appState.llmApiKey
        let model = appState.llmModel
        let endpoint = appState.llmEndpoint
        let lang = appState.appLanguage
        let service = LLMService()

        Task {
            do {
                try await service.testConnection(
                    provider: provider,
                    apiKey: apiKey,
                    model: model,
                    endpoint: endpoint
                )
                await MainActor.run {
                    appState.showSuccess(lang.testSuccess)
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    appState.showError(error.localizedDescription)
                    isTesting = false
                }
            }
            // Refresh Ollama status so UI reflects actual state
            if provider == .ollama {
                await appState.refreshOllamaStatus()
            }
        }
    }
}
