import AVFoundation
import SwiftUI

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
            hotkeyManager.updateModifiers(from: hotkeyModifiers)
        }
    }
    var launchAtLogin: Bool = true {
        didSet { configManager.update { $0.launchAtLogin = launchAtLogin } }
    }
    var soundFeedback: Bool = true {
        didSet { configManager.update { $0.soundFeedback = soundFeedback } }
    }
    var autoPunctuation: Bool = true {
        didSet { configManager.update { $0.autoPunctuation = autoPunctuation } }
    }
    var showInDock: Bool = false {
        didSet { configManager.update { $0.showInDock = showInDock } }
    }

    // MARK: - Model Download State

    var isModelDownloaded: Bool = false
    var isDownloadingModel: Bool = false
    var modelDownloadProgress: Double = 0
    var modelDownloadError: String?

    // MARK: - Hotkey Display

    var hotkeyDisplay: String {
        hotkeyModifiers.map { mod in
            switch mod {
            case "fn": return "Fn"
            case "control": return "\u{2303}"
            case "option": return "\u{2325}"
            case "command": return "\u{2318}"
            case "shift": return "\u{21E7}"
            default: return mod
            }
        }.joined(separator: "")
    }

    var needsModelSetup: Bool { !isModelDownloaded }

    // MARK: - Services

    private let configManager = ConfigManager.shared
    private let modelDownloader = ModelDownloader()
    private let audioRecorder = AudioRecorder()
    let whisperService = WhisperService()
    private let hotkeyManager = HotkeyManager()
    private let textOutputService = TextOutputService()

    // MARK: - Timers

    private var recordingTimer: Timer?
    private var downloadTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        loadFromConfig()
    }

    private func loadFromConfig() {
        let cfg = configManager.config
        appLanguage = AppLanguage(rawValue: cfg.appLanguage) ?? .en
        selectedModel = WhisperModel(rawValue: cfg.selectedModel) ?? .base
        selectedLanguage = Language(rawValue: cfg.selectedLanguage) ?? .auto
        selectedMicrophone = cfg.selectedMicrophone
        hotkeyModifiers = cfg.hotkeyModifiers
        launchAtLogin = cfg.launchAtLogin
        soundFeedback = cfg.soundFeedback
        autoPunctuation = cfg.autoPunctuation
        showInDock = cfg.showInDock
        updateModelStatus()
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

        downloadTask = Task {
            do {
                try await modelDownloader.download(
                    model: selectedModel,
                    to: configManager.modelsDirectory
                )
                self.isDownloadingModel = false
                self.modelDownloadProgress = 1.0
                self.updateModelStatus()
            } catch {
                if !Task.isCancelled {
                    self.modelDownloadError = error.localizedDescription
                }
                self.isDownloadingModel = false
            }
        }

        // Observe progress from downloader
        Task {
            while modelDownloader.isDownloading {
                self.modelDownloadProgress = modelDownloader.progress
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func cancelModelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        modelDownloader.cancel()
        isDownloadingModel = false
        modelDownloadProgress = 0
    }

    func deleteSelectedModel() {
        try? configManager.deleteModel(selectedModel)
        updateModelStatus()
        whisperService.unloadModel()
    }

    // MARK: - Model Loading

    func loadWhisperModel() async throws {
        let folder = configManager.modelFolderPath(for: selectedModel)
        try await whisperService.loadModel(variant: selectedModel.modelName, from: folder)
    }

    // MARK: - Recording Flow

    func startRecording() {
        guard transcriptionState == .idle else { return }

        // Check if model is downloaded
        guard isModelDownloaded else {
            print("[AppState] Cannot record: model not downloaded")
            return
        }

        // Microphone permission prompt is not automatic on macOS; request on first use.
        let micAuth = AVCaptureDevice.authorizationStatus(for: .audio)
        if micAuth != .authorized {
            Task { [weak self] in
                let granted = await AudioRecorder.requestMicrophonePermission()
                await MainActor.run {
                    guard let self else { return }
                    if granted {
                        self.startRecording()
                    } else {
                        print("[AppState] Cannot record: microphone permission not granted")
                    }
                }
            }
            return
        }

        transcriptionState = .recording
        recordingDuration = 0

        do {
            try audioRecorder.startRecording()
            print("[AppState] Recording started")
        } catch {
            print("[AppState] Failed to start recording: \(error)")
            resetToIdle()
            return
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingDuration += 0.1
        }
    }

    func stopRecordingAndProcess() {
        guard transcriptionState == .recording else { return }

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
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let remaining = 0.95 - self.transcriptionProgress
            self.transcriptionProgress += remaining * 0.08
        }
    }

    private func finishProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
        transcriptionProgress = 1.0
    }

    private func processAudio(_ samples: [Float]) {
        transcriptionState = .processing
        startProgressAnimation()

        Task {
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // Load model if not already loaded
                if !whisperService.isModelLoaded {
                    try await loadWhisperModel()
                }

                let text = try await whisperService.transcribe(
                    audioData: samples,
                    language: selectedLanguage
                )

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime

                await MainActor.run {
                    self.finishProgressAnimation()
                    self.transcribedText = text
                    self.processingTime = elapsed
                    self.wordCount = text.split(separator: " ").count
                    self.transcriptionState = .done
                }

                // Output text to current input field
                if !text.isEmpty {
                    await MainActor.run {
                        self.textOutputService.typeText(text)
                    }
                }

                await MainActor.run {
                    self.resetToIdle()
                }
            } catch {
                print("Transcription error: \(error)")
                await MainActor.run {
                    self.finishProgressAnimation()
                    self.resetToIdle()
                }
            }
        }
    }

    // MARK: - Hotkey Management

    func startHotkeyListening() {
        hotkeyManager.updateModifiers(from: hotkeyModifiers)

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
