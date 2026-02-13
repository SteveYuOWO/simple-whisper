import Foundation
import WhisperKit

@Observable
final class WhisperService {
    private var whisperKit: WhisperKit?
    var isModelLoaded: Bool = false

    func loadModel(variant: String, from folder: URL) async throws {
        let config = WhisperKitConfig(
            model: variant,
            modelFolder: folder.path,
            verbose: false,
            prewarm: true
        )
        let kit = try await WhisperKit(config)
        whisperKit = kit
        isModelLoaded = true
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
        isModelLoaded = false
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
