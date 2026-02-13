import Foundation
import WhisperKit

/// Actor-isolated to ensure model loading and inference never run on the main actor
/// and to avoid concurrent access to the underlying WhisperKit instance.
actor WhisperService {
    private var whisperKit: WhisperKit?

    func isModelLoaded() -> Bool {
        whisperKit != nil
    }

    func loadModel(variant: String, from folder: URL) async throws {
        let config = WhisperKitConfig(
            model: variant,
            modelFolder: folder.path,
            verbose: false,
            prewarm: true
        )
        let kit = try await WhisperKit(config)
        whisperKit = kit
    }

    func transcribe(audioData: [Float], language: Language) async throws -> String {
        guard let whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        var options = DecodingOptions()
        options.task = .transcribe
        if language == .auto {
            options.detectLanguage = true
        } else {
            options.language = language.whisperCode
        }

        let results = try await whisperKit.transcribe(audioArray: audioData, decodeOptions: options)

        let text = results
            .flatMap { $0.segments }
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        return text
    }

    func unloadModel() {
        whisperKit = nil
    }

    enum WhisperError: LocalizedError {
        case modelNotLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Whisper model is not loaded"
            }
        }
    }
}
