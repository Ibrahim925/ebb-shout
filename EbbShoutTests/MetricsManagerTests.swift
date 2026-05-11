import XCTest
@testable import EbbShout

final class MetricsManagerTests: XCTestCase {
    var tempDir: URL!
    var manager: MetricsManager!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = MetricsManager(storageDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRecordAndPersist() throws {
        manager.record(words: 50, seconds: 30)
        manager.save()
        let manager2 = MetricsManager(storageDirectory: tempDir)
        XCTAssertEqual(manager2.metrics.totalWords, 50)
    }

    func testStreakIncrementsOnConsecutiveDays() {
        manager.record(words: 10, seconds: 5)
        XCTAssertEqual(manager.metrics.currentStreak, 1)
    }

    func testMinutesSavedFormula() {
        manager.record(words: 130, seconds: 60)
        // 130/40 - 130/130 = 3.25 - 1.0 = 2.25
        XCTAssertEqual(manager.metrics.minutesSaved, 2.25, accuracy: 0.01)
    }

    func testAverageWPM() {
        manager.record(words: 130, seconds: 60)
        XCTAssertEqual(manager.metrics.averageWPM, 130.0, accuracy: 0.1)
    }

    func testLongestStreakUpdated() {
        manager.record(words: 5, seconds: 3)
        XCTAssertEqual(manager.metrics.longestStreak, 1)
    }

    func testReset() {
        manager.record(words: 100, seconds: 60)
        manager.reset()
        XCTAssertEqual(manager.metrics.totalWords, 0)
    }
}
