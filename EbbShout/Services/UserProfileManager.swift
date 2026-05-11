import Foundation

@Observable
final class UserProfileManager {
    private(set) var profile: UserProfile
    private let fileURL: URL
    private var recentOutputs: [String: [String]] = [:]  // mode.rawValue → last 20 enhanced outputs

    init(storageDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                                    .appendingPathComponent("EbbShout")) {
        let dir = storageDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("profile.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = saved
        } else {
            profile = UserProfile()
        }
    }

    func recordRun(transcript: String, mode: RecordingMode, enhancedOutput: String) {
        let words = transcript.split(separator: " ").map(String.init)
        profile.recordWords(words)
        profile.incrementRunCount(for: mode)

        var outputs = recentOutputs[mode.rawValue, default: []]
        outputs.append(enhancedOutput)
        if outputs.count > 20 { outputs.removeFirst() }
        recentOutputs[mode.rawValue] = outputs

        save()
    }

    /// Returns the last 20 enhanced outputs for `mode`, for style summarisation.
    func recentEnhancedOutputs(for mode: RecordingMode) -> [String] {
        recentOutputs[mode.rawValue, default: []]
    }

    func setStyleContext(_ context: String, for mode: RecordingMode) {
        profile.perModeStyle[mode.rawValue] = context
        save()
    }

    func addCustomWord(_ word: String) {
        guard !profile.customVocabulary.contains(word) else { return }
        profile.customVocabulary.append(word)
        save()
    }

    func removeCustomWord(_ word: String) {
        profile.customVocabulary.removeAll { $0 == word }
        save()
    }

    func reset() {
        profile = UserProfile()
        recentOutputs = [:]
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL)
    }
}
