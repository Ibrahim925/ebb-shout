import Foundation

enum RecordingMode: String, CaseIterable, Codable, Identifiable {
    case casual, regular, formal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .regular: "Regular"
        case .formal: "Formal"
        }
    }
    
    

    var systemPrompt: String {
        switch self {
        case .casual:
            return """
            You are a transcription cleaner. The user dictated the following text. \
            Rewrite it in a casual style: all lowercase, minimal punctuation, \
            keep contractions, strip filler words (um, uh, like, you know). \
            Return only the cleaned text, no commentary.
            """
        case .regular:
            return """
            You are a transcription cleaner. The user dictated the following text. \
            Rewrite it with proper capitalisation, light punctuation, natural \
            sentence flow. Strip filler words (um, uh, like, you know). \
            Return only the cleaned text, no commentary.
            """
        case .formal:
            return """
            You are a transcription cleaner. The user dictated the following text. \
            Rewrite it in a formal, professional tone with full punctuation and \
            structured sentences. Intelligently restructure where needed. Strip \
            all filler words. Return only the cleaned text, no commentary.
            """
        }
    }
}
