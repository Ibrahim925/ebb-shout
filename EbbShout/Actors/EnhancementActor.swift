import Foundation

actor EnhancementActor {
    private let ollamaClient: OllamaClient

    init(ollamaClient: OllamaClient) {
        self.ollamaClient = ollamaClient
    }

    func enhance(transcript: String, mode: RecordingMode, styleContext: String?) async throws -> String {
        var systemPrompt = mode.systemPrompt
        if let style = styleContext, !style.isEmpty {
            systemPrompt += "\n\nUser style note: \(style)"
        }
        return try await ollamaClient.enhance(transcript: transcript, systemPrompt: systemPrompt)
    }
}
