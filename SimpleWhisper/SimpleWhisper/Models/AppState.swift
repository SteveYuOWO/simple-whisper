import AVFoundation
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppState {
    // MARK: - Popover State

    var transcriptionState: TranscriptionState = .idle
    var recordingDuration: TimeInterval = 0
    var transcriptionProgress: Double = 0
    var transcribedText: String = ""
    var audioDuration: TimeInterval = 0
    var wordCount: Int = 0
    var processingTime: TimeInterval = 0

    // MARK: - Settings (persisted via ConfigManager)

    var appLanguage: AppLanguage = .en {
        didSet { configManager.update { $0.appLanguage = appLanguage.rawValue } }
    }
    var selectedModel: WhisperModel = .base {
        didSet {
            configManager.update { $0.selectedModel = selectedModel.rawValue }
            updateModelStatus()
        }
    }
    var selectedLanguage: Language = .auto {
        didSet { configManager.update { $0.selectedLanguage = selectedLanguage.rawValue } }
    }
    var selectedMicrophone: String = "Default" {
        didSet { configManager.update { $0.selectedMicrophone = selectedMicrophone } }
    }
    var hotkeyModifiers: [String] = ["fn", "control"] {
        didSet {
            configManager.update { $0.hotkeyModifiers = hotkeyModifiers }
            hotkeyManager.updateHotkey(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
        }
    }
    var hotkeyKeyCode: Int = -1 {
        didSet {
            configManager.update { $0.hotkeyKeyCode = hotkeyKeyCode }
            hotkeyManager.updateHotkey(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
        }
    }
    var launchAtLogin: Bool = true {
        didSet {
            configManager.update { $0.launchAtLogin = launchAtLogin }
            updateLaunchAtLogin(launchAtLogin)
        }
    }
    var soundFeedback: Bool = true {
        didSet { configManager.update { $0.soundFeedback = soundFeedback } }
    }
    // MARK: - LLM Enhancement Settings (persisted)

    var enableLLMEnhancement: Bool = false {
        didSet { configManager.update { $0.enableLLMEnhancement = enableLLMEnhancement } }
    }
    var llmProvider: LLMProvider = .openai {
        didSet {
            configManager.update { $0.llmProvider = llmProvider.rawValue }
            // Auto-select default model for the new provider
            let providerModelIds = llmProvider.models.map(\.id)
            if !providerModelIds.contains(llmModel) {
                llmModel = llmProvider.defaultModel
            }
        }
    }
    var llmApiKey: String = "" {
        didSet { configManager.update { $0.llmApiKey = llmApiKey } }
    }
    var llmModel: String = "" {
        didSet { configManager.update { $0.llmModel = llmModel } }
    }
    var llmEndpoint: String = "" {
        didSet { configManager.update { $0.llmEndpoint = llmEndpoint } }
    }

    var isLLMConfigured: Bool {
        return !llmApiKey.isEmpty
    }

    // MARK: - Model Download State

    var isModelDownloaded: Bool = false
    var isDownloadingModel: Bool = false
    var modelDownloadProgress: Double = 0
    var modelDownloadError: String?

    // MARK: - Notification State

    var errorMessage: String?
    var successMessage: String?
    private var errorDismissTimer: Timer?
    private var successDismissTimer: Timer?

    // MARK: - History

    var transcriptionHistory: [TranscriptionRecord] = []

    // MARK: - Settings Navigation

    var selectedTab: SettingsTab = .input

    // MARK: - Test Input (transient, not persisted)

    var testInputText: String = ""

    // MARK: - Hotkey Recording State (transient, not persisted)

    var isRecordingHotkey: Bool = false
    var recordingModifiers: [String] = []
    var recordingKeyCode: Int = -1
    var pendingHotkeyModifiers: [String] = []
    var pendingHotkeyKeyCode: Int = -1

    // MARK: - Hotkey Display

    func hotkeyDisplayString(modifiers: [String], keyCode: Int = -1) -> String {
        var result = modifiers.map { mod in
            switch mod {
            case "fn": return "Fn"
            case "control": return "\u{2303}"
            case "option": return "\u{2325}"
            case "command": return "\u{2318}"
            case "shift": return "\u{21E7}"
            default: return mod
            }
        }.joined()
        if keyCode >= 0 {
            result += HotkeyManager.keyCodeToDisplayName(keyCode)
        }
        return result
    }

    var hotkeyDisplay: String {
        hotkeyDisplayString(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
    }

    var needsModelSetup: Bool { !isModelDownloaded }

    // MARK: - Services

    private let configManager = ConfigManager.shared
    private let modelDownloader = ModelDownloader()
    private let audioRecorder = AudioRecorder()
    let whisperService = WhisperService()
    private let hotkeyManager = HotkeyManager()
    private let textOutputService = TextOutputService()
    private let llmService = LLMService()
    private let soundService = SoundService.shared
    let updaterManager = UpdaterManager()

    // MARK: - Timers

    private var recordingTimer: Timer?
    private var downloadTask: Task<Void, Never>?
    private var hasPromptedForAccessibility = false

    // MARK: - Init

    init() {
        loadFromConfig()
        transcriptionHistory = configManager.loadHistory()
        syncLaunchAtLoginState()
    }

    private func loadFromConfig() {
        let cfg = configManager.config
        appLanguage = AppLanguage(rawValue: cfg.appLanguage) ?? .en
        selectedModel = WhisperModel(rawValue: cfg.selectedModel) ?? .base
        selectedLanguage = Language(rawValue: cfg.selectedLanguage) ?? .auto
        selectedMicrophone = cfg.selectedMicrophone
        hotkeyModifiers = cfg.hotkeyModifiers
        hotkeyKeyCode = cfg.hotkeyKeyCode
        launchAtLogin = cfg.launchAtLogin
        soundFeedback = cfg.soundFeedback
        enableLLMEnhancement = cfg.enableLLMEnhancement
        llmProvider = LLMProvider(rawValue: cfg.llmProvider) ?? .openai
        llmApiKey = cfg.llmApiKey
        llmEndpoint = cfg.llmEndpoint
        let provider = llmProvider
        llmModel = cfg.llmModel.isEmpty ? provider.defaultModel : cfg.llmModel
        updateModelStatus()
    }

    // MARK: - Launch at Login

    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        let isRegistered = (status == .enabled)
        if launchAtLogin != isRegistered {
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[AppState] Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
        }
    }

    func updateModelStatus() {
        isModelDownloaded = configManager.isModelDownloaded(selectedModel)
    }

    func checkModelStatus() {
        updateModelStatus()
    }

    // MARK: - Model Download

    func downloadSelectedModel() {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        modelDownloadProgress = 0
        modelDownloadError = nil

        let model = selectedModel
        let modelsDir = configManager.modelsDirectory
        let downloader = modelDownloader

        downloadTask = Task.detached(priority: .utility) { [weak self] in
            do {
                try await downloader.download(
                    model: model,
                    to: modelsDir,
                    progressCallback: { [weak self] prog in
                        guard let self else { return }
                        Task { @MainActor in
                            self.modelDownloadProgress = prog.fractionCompleted
                        }
                    }
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isDownloadingModel = false
                    self.modelDownloadProgress = 1.0
                    self.updateModelStatus()
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isDownloadingModel = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if !Task.isCancelled {
                        self.modelDownloadError = error.localizedDescription
                    }
                    self.isDownloadingModel = false
                }
            }
        }
    }

    func cancelModelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloadingModel = false
        modelDownloadProgress = 0
    }

    func deleteSelectedModel() {
        try? configManager.deleteModel(selectedModel)
        updateModelStatus()
        Task {
            await whisperService.unloadModel()
        }
    }

    // MARK: - Model Loading

    func loadWhisperModel() async throws {
        let folder = configManager.modelFolderPath(for: selectedModel)
        try await whisperService.loadModel(variant: selectedModel.modelName, from: folder)
    }

    // MARK: - Error Display

    func showError(_ message: String, navigateTo tab: SettingsTab? = nil) {
        errorDismissTimer?.invalidate()
        errorMessage = message

        if let tab {
            selectedTab = tab
            NSApp.activate(ignoringOtherApps: true)
        }

        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissError()
            }
        }
    }

    func showSuccess(_ message: String) {
        successDismissTimer?.invalidate()
        successMessage = message

        successDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissSuccess()
            }
        }
    }

    func dismissError() {
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
        errorMessage = nil
    }

    func dismissSuccess() {
        successDismissTimer?.invalidate()
        successDismissTimer = nil
        successMessage = nil
    }

    // MARK: - Recording Flow

    func startRecording() {
        let lang = appLanguage

        // 1. Check if already processing
        guard transcriptionState == .idle else {
            showError(lang.errorAlreadyProcessing)
            return
        }

        // 2. Check microphone permission
        let micStatus = AudioRecorder.microphonePermissionStatus()
        print("[AppState] Mic permission status=\(micStatus.rawValue)")
        switch micStatus {
        case .granted:
            break
        case .undetermined:
            Task { [weak self] in
                let granted = await AudioRecorder.requestMicrophonePermission()
                await MainActor.run {
                    guard let self else { return }
                    if granted {
                        self.startRecording()
                    } else {
                        self.showError(lang.errorNoMicPermission, navigateTo: .input)
                    }
                }
            }
            return
        case .denied:
            showError(lang.errorNoMicPermission, navigateTo: .input)
            return
        }

        // 3. Check if model is downloaded
        guard isModelDownloaded else {
            showError(lang.errorNoModel, navigateTo: .model)
            return
        }

        // 4. Check LLM configuration
        if enableLLMEnhancement && !isLLMConfigured {
            showError(lang.errorLLMNotConfigured, navigateTo: .ai)
            return
        }

        transcriptionState = .recording
        recordingDuration = 0

        if soundFeedback { soundService.playStart() }

        do {
            try audioRecorder.startRecording()
            print("[AppState] Recording started")
        } catch {
            print("[AppState] Failed to start recording: \(error)")
            if let recErr = error as? AudioRecorder.RecordingError, recErr == .noMicrophonePermission {
                showError(lang.errorNoMicPermission, navigateTo: .input)
                return
            }
            resetToIdle()
            return
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingDuration += 0.1
            }
        }
    }

    func stopRecordingAndProcess() {
        guard transcriptionState == .recording else { return }

        if soundFeedback { soundService.playStop() }

        recordingTimer?.invalidate()
        recordingTimer = nil
        audioDuration = recordingDuration

        let samples = audioRecorder.stopRecording()

        // Skip if recording was too short (< 0.3s)
        let minSampleCount = Int(16000 * 0.3)
        guard samples.count > minSampleCount else {
            print("[AppState] Recording ended but audio was too short or empty. duration=\(String(format: "%.2f", audioDuration))s samples=\(samples.count)")
            resetToIdle()
            return
        }

        processAudio(samples)
    }

    private var progressTimer: Timer?

    private func startProgressAnimation() {
        transcriptionProgress = 0
        progressTimer?.invalidate()
        // Animate progress from 0 to ~0.9 over time, slowing down as it approaches 1
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let remaining = 0.95 - self.transcriptionProgress
                self.transcriptionProgress += remaining * 0.08
            }
        }
    }

    private func finishProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
        transcriptionProgress = 1.0
    }

    /// Minimum display duration for processing and done states
    private static let minStateDuration: UInt64 = 500_000_000 // 500ms in nanoseconds

    private func processAudio(_ samples: [Float]) {
        transcriptionState = .processing
        startProgressAnimation()

        Task {
            let processingStart = ContinuousClock.now
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // Load model if not already loaded
                if !(await whisperService.isModelLoaded()) {
                    try await loadWhisperModel()
                }

                let langCode = selectedLanguage.whisperCode
                // Mixed-language prompt to guide Whisper for Chinese-English code-switching
                let prompt: String? = (langCode == "zh" || langCode == nil)
                    ? "这是一段中英文混合的语音，其中可能包含English words和技术术语如API、iPhone、Python等。"
                    : nil
                let text = try await whisperService.transcribe(
                    audioData: samples,
                    whisperCode: langCode,
                    promptText: prompt
                )

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime

                // Ensure processing state is visible for at least 500ms
                let processingElapsed = ContinuousClock.now - processingStart
                if processingElapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - processingElapsed)
                }

                await MainActor.run {
                    self.finishProgressAnimation()
                    self.transcribedText = text
                    self.processingTime = elapsed
                    self.wordCount = text.split(separator: " ").count
                }

                // LLM Enhancement step
                var finalText = text
                if await MainActor.run(body: { self.enableLLMEnhancement && self.isLLMConfigured }) {
                    await MainActor.run {
                        self.transcriptionState = .enhancing
                        self.startProgressAnimation()
                    }

                    let provider = await MainActor.run { self.llmProvider }
                    let apiKey = await MainActor.run { self.llmApiKey }
                    let model = await MainActor.run { self.llmModel }
                    let endpoint = await MainActor.run { self.llmEndpoint }

                    do {
                        let enhanced = try await self.llmService.enhance(
                            text: text,
                            provider: provider,
                            apiKey: apiKey,
                            model: model,
                            endpoint: endpoint
                        )
                        finalText = enhanced
                        await MainActor.run {
                            self.transcribedText = enhanced
                            self.wordCount = enhanced.split(separator: " ").count
                        }
                    } catch {
                        print("[AppState] LLM enhancement failed: \(error). Using original text.")
                    }

                    await MainActor.run {
                        self.finishProgressAnimation()
                    }
                }

                await MainActor.run {
                    self.transcriptionState = .done

                    // Save to history
                    if !self.transcribedText.isEmpty {
                        let record = TranscriptionRecord(
                            id: UUID(),
                            timestamp: Date(),
                            text: self.transcribedText,
                            audioDuration: self.audioDuration,
                            processingTime: self.processingTime,
                            wordCount: self.wordCount
                        )
                        self.transcriptionHistory.append(record)
                        self.configManager.saveHistory(self.transcriptionHistory)
                    }
                }

                // Output text to current input field
                if !finalText.isEmpty {
                    await MainActor.run {
                        self.textOutputService.typeText(finalText)
                    }
                }

                // Ensure done state is visible for at least 500ms
                try? await Task.sleep(for: .milliseconds(500))

                await MainActor.run {
                    self.resetToIdle()
                }
            } catch {
                print("Transcription error: \(error)")
                // Ensure processing state is visible for at least 500ms even on error
                let processingElapsed = ContinuousClock.now - processingStart
                if processingElapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - processingElapsed)
                }
                await MainActor.run {
                    self.finishProgressAnimation()
                    self.resetToIdle()
                }
            }
        }
    }

    // MARK: - Hotkey Management

    func startHotkeyListening() {
        // Check accessibility permission before starting hotkey listening
        guard HotkeyManager.isAccessibilityGranted() else {
            print("[AppState] Accessibility permission not granted for hotkey")

            // Only prompt once per session to avoid annoying the user
            if !hasPromptedForAccessibility {
                HotkeyManager.requestAccessibility()
                let lang = appLanguage
                showError(lang.errorNoAccessibilityPermission, navigateTo: .input)
                hasPromptedForAccessibility = true
            }
            return
        }

        // Permission granted, reset prompt flag in case it was denied before
        hasPromptedForAccessibility = false

        hotkeyManager.updateHotkey(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)

        hotkeyManager.onKeyDown = { [weak self] in
            self?.startRecording()
        }

        hotkeyManager.onKeyUp = { [weak self] in
            self?.stopRecordingAndProcess()
        }

        hotkeyManager.start()
    }

    func stopHotkeyListening() {
        hotkeyManager.stop()
    }

    // MARK: - Hotkey Recording

    func startRecordingHotkey() {
        guard HotkeyManager.isAccessibilityGranted() else { return }
        hotkeyManager.stop()
        isRecordingHotkey = true
        recordingModifiers = []
        recordingKeyCode = -1
        pendingHotkeyModifiers = []
        pendingHotkeyKeyCode = -1
        hotkeyManager.startMonitor { [weak self] modifiers, keyCode in
            guard let self else { return }
            let prevEmpty = self.recordingModifiers.isEmpty && self.recordingKeyCode < 0
            self.recordingModifiers = modifiers
            self.recordingKeyCode = Int(keyCode)

            let currentTotal = modifiers.count + (keyCode >= 0 ? 1 : 0)
            let pendingTotal = self.pendingHotkeyModifiers.count + (self.pendingHotkeyKeyCode >= 0 ? 1 : 0)

            if currentTotal > 0 {
                if prevEmpty || currentTotal >= pendingTotal {
                    self.pendingHotkeyModifiers = modifiers
                    self.pendingHotkeyKeyCode = Int(keyCode)
                }
            }
        }
    }

    var hasPendingHotkey: Bool {
        !pendingHotkeyModifiers.isEmpty || pendingHotkeyKeyCode >= 0
    }

    func confirmRecordingHotkey() {
        guard hasPendingHotkey else { return }
        hotkeyModifiers = pendingHotkeyModifiers
        hotkeyKeyCode = pendingHotkeyKeyCode
        cancelRecordingHotkey()
    }

    func cancelRecordingHotkey() {
        isRecordingHotkey = false
        hotkeyManager.stopMonitor()
        recordingModifiers = []
        recordingKeyCode = -1
        pendingHotkeyModifiers = []
        pendingHotkeyKeyCode = -1
        startHotkeyListening()
    }

    // MARK: - History Management

    func deleteHistoryRecord(id: UUID) {
        transcriptionHistory.removeAll { $0.id == id }
        configManager.saveHistory(transcriptionHistory)
    }

    func clearHistory() {
        transcriptionHistory.removeAll()
        configManager.saveHistory(transcriptionHistory)
    }

    // MARK: - Reset

    func resetToIdle() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        transcriptionState = .idle
        transcribedText = ""
        recordingDuration = 0
        transcriptionProgress = 0
    }

}
