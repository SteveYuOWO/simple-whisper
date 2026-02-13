import Foundation

final class LLMService {
    static let systemPrompt = """
        You are a transcription post-processor. Clean up the following speech-to-text output.

        Rules:
        1. Remove any timestamp markers (e.g., <|0.00|>, <|2.00|>)
        2. Fix typos, wrong characters, and misrecognized words (e.g., "How are u" → "How are you?"), but NEVER translate between languages
        3. Make the text fluent and natural, but keep each part in its original language — do NOT translate Chinese to English or English to Chinese
        4. For mixed Chinese-English text: the speaker intentionally code-switches. Keep every English word/phrase in English and every Chinese word/phrase in Chinese. Example: "早上好 How are u" → "早上好 How are you?" (NOT "早上好，今天怎么样")
        5. Preserve the speaker's original meaning — do not add, remove, or change the intent
        6. Output ONLY the cleaned text, no explanations or metadata

        Formatting rules:
        - When the speaker lists multiple items (e.g., "第一...第二..." / "一、...二、..." / "首先...然后..." / "first...second..."), format as a numbered list with each item on its own line
        - When the speaker changes topic or starts a new thought, insert a line break
        - Use a blank line to separate the introductory sentence from the list
        - For short, single-topic speech with no enumeration: output as one paragraph, no extra line breaks
        """

    func enhance(
        text: String,
        provider: LLMProvider,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws -> String {
        switch provider {
        case .openai:
            let url = endpoint.isEmpty ? provider.defaultEndpoint : endpoint
            return try await callOpenAI(text: text, apiKey: apiKey, model: model, endpoint: url)
        case .claude:
            let url = endpoint.isEmpty ? provider.defaultEndpoint : endpoint
            return try await callClaude(text: text, apiKey: apiKey, model: model, endpoint: url)
        }
    }

    /// Test connectivity based on provider type
    func testConnection(
        provider: LLMProvider,
        apiKey: String,
        model: String,
        endpoint: String
    ) async throws {
        guard !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let testText = "Hello, this is a test."
        _ = try await enhance(text: testText, provider: provider, apiKey: apiKey, model: model, endpoint: endpoint)
    }

    // MARK: - OpenAI API

    private func callOpenAI(
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model.isEmpty ? LLMProvider.openai.defaultModel : model,
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

    // MARK: - Claude (Anthropic) API

    private func callClaude(
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
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model.isEmpty ? LLMProvider.claude.defaultModel : model,
            "max_tokens": 4096,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
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
              let contentArray = json["content"] as? [[String: Any]],
              let firstBlock = contentArray.first,
              let content = firstBlock["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case missingAPIKey
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .missingAPIKey:
            return "API key is required"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
