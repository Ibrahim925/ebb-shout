import Foundation

actor TranscriptionActor {
    private let ollamaClient: OllamaClient

    init(ollamaClient: OllamaClient) {
        self.ollamaClient = ollamaClient
    }

    func transcribe(audioURL: URL, vocabularyHint: String?, model: String = "whisper") async throws -> String {
        let hint = vocabularyHint.flatMap { $0.isEmpty ? nil : $0 }
        return try await ollamaClient.transcribe(audioURL: audioURL, hint: hint, model: model)
    }
}
