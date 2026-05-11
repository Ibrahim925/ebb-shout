import Foundation

struct Metrics: Codable {
    var totalWords: Int = 0
    var totalRecordingSeconds: Double = 0
    var dailyWordCounts: [String: Int] = [:]  // "YYYY-MM-DD" → word count
    var longestStreak: Int = 0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func todayKey() -> String {
        dateFormatter.string(from: Date())
    }

    mutating func record(words: Int, seconds: Double) {
        totalWords += words
        totalRecordingSeconds += seconds
        dailyWordCounts[Self.todayKey(), default: 0] += words
    }

    /// Consecutive days up to and including today with at least 1 word.
    var currentStreak: Int {
        var streak = 0
        var date = Date()
        let cal = Calendar.current
        while true {
            let key = Self.dateFormatter.string(from: date)
            guard (dailyWordCounts[key] ?? 0) > 0 else { break }
            streak += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return streak
    }

    /// Estimated minutes saved: speaking at 130 wpm vs typing at 40 wpm.
    var minutesSaved: Double {
        Double(totalWords) / 40.0 - Double(totalWords) / 130.0
    }

    var averageWPM: Double {
        guard totalRecordingSeconds > 0 else { return 0 }
        return Double(totalWords) / (totalRecordingSeconds / 60.0)
    }

    /// Activity counts for the last `weeks` weeks, ordered oldest→newest.
    func heatmapData(weeks: Int = 12) -> [(date: String, count: Int)] {
        let cal = Calendar.current
        var results: [(String, Int)] = []
        var date = Date()
        for _ in 0 ..< weeks * 7 {
            let key = Self.dateFormatter.string(from: date)
            results.append((key, dailyWordCounts[key] ?? 0))
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return results.reversed()
    }
}
