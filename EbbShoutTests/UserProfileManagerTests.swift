import XCTest
@testable import EbbShout

final class UserProfileManagerTests: XCTestCase {
    var tempDir: URL!
    var manager: UserProfileManager!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = UserProfileManager(storageDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRecordWordsBuildsFrequency() {
        manager.recordRun(transcript: "SwiftUI SwiftUI SwiftUI SwiftUI SwiftUI", mode: .regular, enhancedOutput: "")
        XCTAssertEqual(manager.profile.wordFrequency["swiftui"], 5)
    }

    func testCandidateVocabularyExcludesCommonWords() {
        for _ in 0..<5 { manager.recordRun(transcript: "the swiftui", mode: .regular, enhancedOutput: "") }
        let candidates = manager.profile.candidateVocabulary(excluding: ["the"])
        XCTAssertTrue(candidates.contains("swiftui"))
        XCTAssertFalse(candidates.contains("the"))
    }

    func testPersistsAcrossInstances() {
        manager.addCustomWord("Ibrahim")
        manager.save()
        let manager2 = UserProfileManager(storageDirectory: tempDir)
        XCTAssertTrue(manager2.profile.customVocabulary.contains("Ibrahim"))
    }

    func testVocabHintJoinsCustomWords() {
        manager.addCustomWord("Ollama")
        manager.addCustomWord("SwiftUI")
        XCTAssertTrue(manager.profile.vocabularyHint.contains("Ollama"))
    }

    func testStyleRegenerationTriggersAt20Runs() {
        for i in 0..<20 {
            manager.recordRun(transcript: "test", mode: .formal, enhancedOutput: "Enhanced \(i)")
        }
        XCTAssertTrue(manager.profile.shouldRegenerateStyle(for: .formal))
    }

    func testRecentOutputsTracked() {
        manager.recordRun(transcript: "hello", mode: .casual, enhancedOutput: "hey")
        XCTAssertEqual(manager.recentEnhancedOutputs(for: .casual), ["hey"])
    }

    func testRecentOutputsCappedAt20() {
        for i in 0..<25 {
            manager.recordRun(transcript: "test", mode: .casual, enhancedOutput: "Output \(i)")
        }
        XCTAssertEqual(manager.recentEnhancedOutputs(for: .casual).count, 20)
    }

    func testRemoveCustomWord() {
        manager.addCustomWord("TestWord")
        manager.removeCustomWord("TestWord")
        XCTAssertFalse(manager.profile.customVocabulary.contains("TestWord"))
    }

    func testReset() {
        manager.addCustomWord("TestWord")
        manager.recordRun(transcript: "hello", mode: .regular, enhancedOutput: "Hello.")
        manager.reset()
        XCTAssertTrue(manager.profile.customVocabulary.isEmpty)
        XCTAssertTrue(manager.recentEnhancedOutputs(for: .regular).isEmpty)
    }
}
