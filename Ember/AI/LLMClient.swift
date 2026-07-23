import Foundation

/// Errors surfaced by the LLM client, mapped to user-friendly messages.
enum LLMError: LocalizedError {
    case missingKey
    case http(Int, String)
    case emptyResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No API key set. Add your OpenRouter key in Settings."
        case .http(let code, let body): return "AI request failed (HTTP \(code)). \(body)"
        case .emptyResponse: return "The AI returned an empty response."
        case .decoding(let detail): return "Couldn't read the AI response: \(detail)"
        }
    }
}

/// Thin client for an OpenAI-compatible `chat/completions` endpoint (default:
/// OpenRouter). Kept deliberately generic so the model and base URL are
/// configurable from Settings.
///
/// SECURITY: the API key travels from the device straight to the provider. This
/// is fine for personal/dev use; a production app should route through a backend
/// that holds the key. See `Keychain` for the same caveat.
struct LLMClient {
    var apiKey: String
    var model: String
    var baseURL: String

    static let defaultModel = "anthropic/claude-sonnet-4.5"
    static let defaultBaseURL = "https://openrouter.ai/api/v1"

    /// One turn in a chat conversation ("user" or "assistant").
    struct ChatTurn {
        let role: String
        let content: String
    }

    /// Send a system + single user prompt, asking for a JSON object (used by the
    /// calendar categorizer). Low temperature for stable parsing.
    func complete(system: String, user: String) async throws -> String {
        try await send(system: system,
                       turns: [ChatTurn(role: "user", content: user)],
                       jsonObject: true, temperature: 0.2)
    }

    /// Multi-turn chat (used by the Rest Coach). Free-form text, warmer temperature.
    func chat(system: String, messages: [ChatTurn]) async throws -> String {
        try await send(system: system, turns: messages, jsonObject: false, temperature: 0.4)
    }

    /// Streaming multi-turn chat: yields assistant text deltas as they arrive
    /// (OpenAI-compatible Server-Sent Events). Used by the Rest Coach for
    /// token-by-token rendering.
    func chatStream(system: String, messages: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(system: system, turns: messages,
                                                  jsonObject: false, temperature: 0.4, stream: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.decoding("No HTTP response.")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw LLMError.http(http.statusCode, "")
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let piece = delta["content"] as? String else { continue }
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func send(system: String, turns: [ChatTurn],
                      jsonObject: Bool, temperature: Double) async throws -> String {
        let request = try makeRequest(system: system, turns: turns,
                                      jsonObject: jsonObject, temperature: temperature, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.decoding("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, String(text.prefix(300)))
        }
        // OpenAI-compatible shape: choices[0].message.content
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw LLMError.emptyResponse
        }
        return content
    }

    private func makeRequest(system: String, turns: [ChatTurn],
                             jsonObject: Bool, temperature: Double, stream: Bool) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw LLMError.missingKey }
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.decoding("Invalid base URL.")
        }

        var messages: [[String: Any]] = [["role": "system", "content": system]]
        messages.append(contentsOf: turns.map { ["role": $0.role, "content": $0.content] })

        var body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": messages
        ]
        if jsonObject { body["response_format"] = ["type": "json_object"] }
        if stream { body["stream"] = true }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        // Optional OpenRouter attribution headers (harmless on other providers).
        request.setValue("https://github.com/bluebox/ember", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Ember", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60
        return request
    }
}
