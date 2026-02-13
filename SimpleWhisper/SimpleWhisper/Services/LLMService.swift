import Foundation

final class LLMService {
    static let systemPrompt = """
        Clean up the speech-to-text transcription below. Remove filler words, fix punctuation, and correct obvious errors. Keep the original language and meaning. Output only the cleaned text.
        """

    func enhance(
        text: String,
        provider: LLMProvider,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws -> String {
        let ollamaEndpoint = endpoint.isEmpty ? "http://localhost:11434" : endpoint
        return try await callOpenAICompatible(
            text: text,
            apiKey: apiKey,
            model: model,
            endpoint: ollamaEndpoint.hasSuffix("/v1/chat/completions")
                ? ollamaEndpoint
                : ollamaEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
        )
    }

    /// Test connectivity based on provider type
    func testConnection(
        provider: LLMProvider,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws {
        switch provider {
        case .ollama:
            // For Ollama: check installation, service status, and model availability
            let ollamaManager = OllamaManager.shared

            // 1. Check if Ollama service is reachable (covers both local and remote)
            let running = await ollamaManager.isOllamaRunning()

            if !running {
                // Service not reachable — check if binary is installed locally
                if !ollamaManager.checkOllamaInstalled() {
                    throw LLMError.ollamaNotInstalled
                }
                throw LLMError.ollamaNotRunning
            }

            // 3. Check if the selected model exists
            let installedModels = try await ollamaManager.listInstalledModels()
            guard !installedModels.isEmpty else {
                throw LLMError.noModelsInstalled
            }

            guard installedModels.contains(model) else {
                throw LLMError.modelNotFound(model)
            }

            // Success: Ollama is ready
            print("[LLMService] Ollama connection test passed: service running, model '\(model)' available")
        }
    }

    // MARK: - OpenAI-Compatible API

    private func callOpenAICompatible(
        text: String,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case ollamaNotInstalled
    case ollamaNotRunning
    case noModelsInstalled
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .ollamaNotInstalled:
            return "Ollama is not installed"
        case .ollamaNotRunning:
            return "Ollama service is not running"
        case .noModelsInstalled:
            return "No models installed"
        case .modelNotFound(let model):
            return "Model '\(model)' not found"
        }
    }
}
