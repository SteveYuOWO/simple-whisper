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

    // MARK: - Settings

    var selectedModel: WhisperModel = .base
    var selectedLanguage: Language = .auto
    var selectedMicrophone: String = "Default"
    var hotkeyDisplay: String = "Fn"
    var launchAtLogin: Bool = true
    var soundFeedback: Bool = true
    var autoPunctuation: Bool = true
    var showInDock: Bool = false

    // MARK: - Debug

    var debugPanelController: FloatingPanelController?

    // MARK: - Timers (for mock simulation)

    private var recordingTimer: Timer?
    private var processingTimer: Timer?

    // MARK: - Mock State Transitions

    func simulateFullCycle() {
        transcriptionState = .recording
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.recordingDuration += 0.1
            if self.recordingDuration >= 3.0 {
                timer.invalidate()
                self.recordingTimer = nil
                self.audioDuration = self.recordingDuration
                self.beginProcessing()
            }
        }
    }

    private func beginProcessing() {
        transcriptionState = .processing
        transcriptionProgress = 0

        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.transcriptionProgress += 0.05
            if self.transcriptionProgress >= 1.0 {
                timer.invalidate()
                self.processingTimer = nil
                self.finishProcessing()
            }
        }
    }

    private func finishProcessing() {
        transcriptionState = .done
        transcribedText = "Hey, can we schedule a meeting for tomorrow at 3pm? I'd like to discuss the project timeline."
        processingTime = 0.8
        wordCount = 18

        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.resetToIdle()
        }
    }

    func resetToIdle() {
        recordingTimer?.invalidate()
        processingTimer?.invalidate()
        recordingTimer = nil
        processingTimer = nil
        transcriptionState = .idle
        transcribedText = ""
        recordingDuration = 0
        transcriptionProgress = 0
    }
}
