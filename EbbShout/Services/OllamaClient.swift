import Foundation

enum OllamaError: Error {
    case httpError(Int)
    case decodingError
}

private extension URL {
    static let ollamaDefault = URL(string: "http://localhost:11434")! // safe: known-valid literal
}

final class OllamaClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = .ollamaDefault, session: URLSession = .shared) {
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
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw OllamaError.decodingError
        }
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.appendUTF8("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.appendUTF8("\r\n")
        if let hint, !hint.isEmpty {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            body.appendUTF8(hint)
            body.appendUTF8("\r\n")
        }
        body.appendUTF8("--\(boundary)--\r\n")
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

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
