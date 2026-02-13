import Foundation

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let text: String
    let audioDuration: TimeInterval
    let processingTime: TimeInterval
    let wordCount: Int
}

struct AppConfig: Codable {
    var selectedModel: String = WhisperModel.base.rawValue
    var selectedLanguage: String = Language.auto.rawValue
    var appLanguage: String = AppLanguage.en.rawValue
    var launchAtLogin: Bool = true
    var soundFeedback: Bool = true
    var selectedMicrophone: String = "Default"
    var hotkeyModifiers: [String] = ["fn", "control"]
    var hotkeyKeyCode: Int = -1

    // LLM Enhancement
    var enableLLMEnhancement: Bool = false
    var llmProvider: String = LLMProvider.openai.rawValue
    var llmApiKey: String = ""
    var llmModel: String = ""
    var llmEndpoint: String = ""
}

final class ConfigManager {
    static let shared = ConfigManager()

    private let baseDirectory: URL
    let modelsDirectory: URL
    private let configFileURL: URL
    private let historyFileURL: URL

    private(set) var config: AppConfig

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        baseDirectory = home.appendingPathComponent(".simple-whisper")
        modelsDirectory = baseDirectory.appendingPathComponent("models")
        configFileURL = baseDirectory.appendingPathComponent("config.json")
        historyFileURL = baseDirectory.appendingPathComponent("history.json")

        // Ensure directories exist
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Load or create default config
        config = ConfigManager.loadConfig(from: configFileURL) ?? AppConfig()
    }

    private static func loadConfig(from url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configFileURL, options: .atomic)
    }

    func update(_ block: (inout AppConfig) -> Void) {
        block(&config)
        save()
    }

    func modelFolderPath(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.modelName)
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let folder = modelFolderPath(for: model)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        // Check for at least one .mlmodelc file
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return contents.contains { $0.hasSuffix(".mlmodelc") || $0.hasSuffix(".mlpackage") || $0 == "config.json" }
    }

    func deleteModel(_ model: WhisperModel) throws {
        let folder = modelFolderPath(for: model)
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    // MARK: - History

    private static let maxHistoryRecords = 100

    func loadHistory() -> [TranscriptionRecord] {
        guard let data = try? Data(contentsOf: historyFileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranscriptionRecord].self, from: data)) ?? []
    }

    func saveHistory(_ records: [TranscriptionRecord]) {
        let trimmed = records.count > Self.maxHistoryRecords
            ? Array(records.suffix(Self.maxHistoryRecords))
            : records
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(trimmed) else { return }
        try? data.write(to: historyFileURL, options: .atomic)
    }
}
