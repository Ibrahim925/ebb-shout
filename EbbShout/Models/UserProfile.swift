import Foundation

struct UserProfile: Codable {
    var wordFrequency: [String: Int] = [:]
    var customVocabulary: [String] = []
    var perModeStyle: [String: String] = [:]  // keyed by RecordingMode.rawValue
    var runCountPerMode: [String: Int] = [:]  // for style-regen trigger

    var vocabularyHint: String {
        customVocabulary.joined(separator: ", ")
    }

    func styleContext(for mode: RecordingMode) -> String? {
        perModeStyle[mode.rawValue]
    }

    mutating func recordWords(_ words: [String]) {
        for word in words {
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard !lower.isEmpty else { continue }
            wordFrequency[lower, default: 0] += 1
        }
    }

    mutating func incrementRunCount(for mode: RecordingMode) {
        runCountPerMode[mode.rawValue, default: 0] += 1
    }

    func shouldRegenerateStyle(for mode: RecordingMode) -> Bool {
        let count = runCountPerMode[mode.rawValue, default: 0]
        return count > 0 && count % 20 == 0
    }

    /// Words appearing ≥ 5 times that are not in the common word exclusion list.
    func candidateVocabulary(excluding common: Set<String>) -> [String] {
        wordFrequency
            .filter { $0.value >= 5 && !common.contains($0.key) }
            .map(\.key)
            .sorted()
    }
}
