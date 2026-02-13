import Foundation

/// Manages Ollama installation, model downloading, and process lifecycle
final class OllamaManager {
    static let shared = OllamaManager()

    // Recommended small models for transcription enhancement
    static let recommendedModels: [(name: String, size: String)] = [
        ("qwen2.5:0.5b", "~400 MB"),
        ("llama3.2:1b", "~1.3 GB"),
        ("qwen2.5:1.5b", "~1 GB")
    ]

    private var ollamaProcess: Process?
    private let ollamaEndpoint = "http://localhost:11434"

    private init() {}

    // MARK: - Installation Check

    /// Check if Ollama is installed by looking for the binary in common locations
    func checkOllamaInstalled() -> Bool {
        let possiblePaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "\(NSHomeDirectory())/.local/bin/ollama"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Try `which ollama`
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["ollama"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !output.isEmpty && task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Get the Ollama binary path
    private func getOllamaPath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "\(NSHomeDirectory())/.local/bin/ollama"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try `which ollama`
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["ollama"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !output.isEmpty && task.terminationStatus == 0 {
                return output
            }
        } catch {
            return nil
        }

        return nil
    }

    // MARK: - Service Management

    /// Check if Ollama service is running by attempting to connect
    func isOllamaRunning() async -> Bool {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// Start Ollama service in the background
    func startOllama() async throws {
        guard let ollamaPath = getOllamaPath() else {
            throw OllamaError.notInstalled
        }

        // Check if already running
        if await isOllamaRunning() {
            print("[OllamaManager] Ollama is already running")
            return
        }

        // Start Ollama serve in background
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["serve"]

        // Redirect output to avoid zombie processes
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        ollamaProcess = process

        print("[OllamaManager] Started Ollama service")

        // Wait for service to be ready (up to 5 seconds)
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(500))
            if await isOllamaRunning() {
                print("[OllamaManager] Ollama service is ready")
                return
            }
        }

        throw OllamaError.failedToStart
    }

    /// Stop Ollama service
    func stopOllama() {
        ollamaProcess?.terminate()
        ollamaProcess = nil
        print("[OllamaManager] Stopped Ollama service")
    }

    // MARK: - Model Management

    /// List installed Ollama models
    func listInstalledModels() async throws -> [String] {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            throw OllamaError.invalidEndpoint
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }

        return models.compactMap { model in
            model["name"] as? String
        }
    }

    /// Pull (download) an Ollama model
    func pullModel(name: String, progressCallback: @escaping (Double) -> Void) async throws {
        guard let url = URL(string: "\(ollamaEndpoint)/api/pull") else {
            throw OllamaError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600 // 10 minutes

        let body: [String: Any] = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use URLSession with delegate for streaming progress
        let session = URLSession.shared
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.apiError
        }

        var currentProgress: Double = 0
        var totalSize: Int64 = 0
        var downloadedSize: Int64 = 0

        for try await line in asyncBytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Parse progress from Ollama's streaming response
            if let total = json["total"] as? Int64 {
                totalSize = total
            }
            if let completed = json["completed"] as? Int64 {
                downloadedSize = completed
            }

            if totalSize > 0 {
                currentProgress = Double(downloadedSize) / Double(totalSize)
                await MainActor.run {
                    progressCallback(currentProgress)
                }
            }

            // Check if download is complete
            if let status = json["status"] as? String, status == "success" {
                await MainActor.run {
                    progressCallback(1.0)
                }
                print("[OllamaManager] Model \(name) downloaded successfully")
                return
            }
        }
    }

    /// Delete an Ollama model
    func deleteModel(name: String) async throws {
        guard let url = URL(string: "\(ollamaEndpoint)/api/delete") else {
            throw OllamaError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.apiError
        }

        print("[OllamaManager] Model \(name) deleted successfully")
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case notInstalled
    case failedToStart
    case invalidEndpoint
    case apiError

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Ollama is not installed. Please install it from https://ollama.ai"
        case .failedToStart:
            return "Failed to start Ollama service"
        case .invalidEndpoint:
            return "Invalid Ollama endpoint"
        case .apiError:
            return "Ollama API error"
        }
    }
}
