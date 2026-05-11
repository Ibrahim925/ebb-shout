import Foundation

enum OllamaError: Error {
    case httpError(Int)
    case decodingError
}

final class OllamaClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:11434")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Sends audio file to Ollama Whisper endpoint and returns raw transcript.
    func transcribe(audioURL: URL, hint: String?) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/audio/transcriptions"))
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        if let hint, !hint.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(hint.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.decodingError }
        guard http.statusCode == 200 else { throw OllamaError.httpError(http.statusCode) }

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw OllamaError.decodingError
        }
        return decoded.text
    }

    /// Sends transcript to Gemma via Ollama generate endpoint and returns enhanced text.
    func enhance(transcript: String, systemPrompt: String, model: String = "gemma3:4b") async throws -> String {
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
