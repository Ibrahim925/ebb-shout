import XCTest
@testable import EbbShout

final class TranscriptionActorTests: XCTestCase {
    func testTranscribeThrowsWithoutExecutable() async throws {
        let actor = TranscriptionActor()
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("missing-executable.wav")
        try Data().write(to: audioURL)

        do {
            _ = try await actor.transcribe(
                audioURL: audioURL,
                vocabularyHint: nil,
                executablePath: "",
                modelPath: "/tmp/model.bin"
            )
            XCTFail("Expected missing executable")
        } catch TranscriptionError.missingExecutable {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeThrowsWithoutModelPath() async throws {
        let actor = TranscriptionActor()
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("missing-model.wav")
        try Data().write(to: audioURL)

        do {
            _ = try await actor.transcribe(
                audioURL: audioURL,
                vocabularyHint: nil,
                executablePath: "whisper-cli",
                modelPath: ""
            )
            XCTFail("Expected missing model path")
        } catch TranscriptionError.missingModelPath {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscriptExtractionRemovesWhisperLogs() {
        let output = """
        whisper_model_load: loading model
        system_info: n_threads = 4
        main: processing audio.wav
        Hello world.
        This is local.
        """

        XCTAssertEqual(TranscriptionActor.extractTranscript(from: output), "Hello world. This is local.")
    }

    func testTranscriptExtractionRemovesMetalLogsAndControlCharacters() {
        let output = """
        \u{1}\u{1}Testing.
        ggml_metal_device_init: Tensor API disabled for pre-M5 and pre-A19 devices.
        ggml_metal_library_init: Using embedded Metal library.
        ggml_metal_device_init: GPU name: MTL0 (Apple M4 Pro).
        """

        XCTAssertEqual(TranscriptionActor.extractTranscript(from: output), "Testing.")
    }
}
