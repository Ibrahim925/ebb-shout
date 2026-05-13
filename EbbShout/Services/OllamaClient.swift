import Foundation

enum OllamaError: Error {
    case httpError(Int)
    case decodingError
}

extension URL {
    static let ollamaDefault = URL(string: "http://localhost:11434")! // safe: known-valid literal
}

final class OllamaClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = .ollamaDefault, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Sends transcript to Gemma via Ollama generate endpoint and returns enhanced text.
    func enhance(transcript: String, systemPrompt: String, model: String = "gemma4:latest") async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "prompt": transcript,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.decodingError }
        guard http.statusCode == 200 else { throw OllamaError.httpError(http.statusCode) }

        struct GenerateResponse: Decodable { let response: String }
        guard let decoded = try? JSONDecoder().decode(GenerateResponse.self, from: data) else {
            throw OllamaError.decodingError
        }
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if Ollama is reachable at the configured URL.
    func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 3
        return (try? await session.data(for: request)) != nil
    }
}
