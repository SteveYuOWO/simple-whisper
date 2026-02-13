import SwiftUI

struct SettingsAISection: View {
    @Environment(AppState.self) private var appState
    @State private var isTesting = false

    var body: some View {
        @Bindable var appState = appState
        let lang = appState.appLanguage

        VStack(spacing: DS.settingsSectionGap) {
            // Enable toggle
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
                }
            }

            // Provider + API config
            SettingsGroupCard {
                VStack(spacing: 0) {
                    // Provider picker
                    HStack {
                        Text(lang.aiProvider)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Picker("", selection: $appState.llmProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.displayName(lang)).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)

                    SettingsSeparator()

                    // API Key
                    HStack {
                        Text(lang.apiKey)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        SecureField("sk-...", text: $appState.llmApiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)

                    SettingsSeparator()

                    // Model picker
                    HStack {
                        Text(lang.model)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Picker("", selection: $appState.llmModel) {
                            ForEach(appState.llmProvider.models) { model in
                                Text(model.label(lang)).tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)

                    // Cost estimate
                    if let selectedModel = appState.llmProvider.models.first(where: { $0.id == appState.llmModel }) {
                        SettingsSeparator()

                        HStack {
                            Text(lang.estimatedMonthlyCost)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedModel.costEstimate + lang.perMonth)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: DS.settingsRowHeight)
                        .padding(.horizontal, DS.settingsHPadding)
                    }

                    SettingsSeparator()

                    // Test Connection
                    HStack {
                        Spacer()
                        if isTesting {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(lang.testing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        } else {
                            Button(lang.testConnection, action: testConnection)
                                .disabled(appState.llmApiKey.isEmpty)
                        }
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
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
        }
    }
}
