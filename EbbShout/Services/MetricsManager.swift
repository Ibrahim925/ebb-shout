import Foundation

@Observable
final class MetricsManager {
    private(set) var metrics: Metrics
    private let fileURL: URL

    init(storageDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                                    .appendingPathComponent("EbbShout")) {
        let dir = storageDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("metrics.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(Metrics.self, from: data) {
            metrics = saved
        } else {
            metrics = Metrics()
        }
    }

    func record(words: Int, seconds: Double) {
        metrics.record(words: words, seconds: seconds)
        metrics.longestStreak = max(metrics.longestStreak, metrics.currentStreak)
        save()
    }

    func reset() {
        metrics = Metrics()
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        try? data.write(to: fileURL)
    }
}
