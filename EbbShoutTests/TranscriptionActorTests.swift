import XCTest
@testable import EbbShout

final class TranscriptionActorTests: XCTestCase {
    func makeClient(responseJSON: String) -> OllamaClient {
        MockURLProtocol.handler = { req in
            let body = responseJSON.data(using: .utf8)!
            let res = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (res, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return OllamaClient(baseURL: URL(string: "http://localhost:11434")!,
                            session: URLSession(configuration: config))
    }

    func testTranscribeReturnsText() async throws {
        let client = makeClient(responseJSON: #"{"text":"hello SwiftUI"}"#)
        let actor = TranscriptionActor(ollamaClient: client)
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("t.wav")
        try Data().write(to: audioURL)
        let result = try await actor.transcribe(audioURL: audioURL, vocabularyHint: "SwiftUI")
        XCTAssertEqual(result, "hello SwiftUI")
    }

    func testTranscribeNilHintWhenEmpty() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { req in
            capturedRequest = req
            let body = #"{"text":"hello"}"#.data(using: .utf8)!
            let res = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (res, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OllamaClient(baseURL: URL(string: "http://localhost:11434")!,
                                   session: URLSession(configuration: config))
        let actor = TranscriptionActor(ollamaClient: client)
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("t2.wav")
        try Data().write(to: audioURL)
        _ = try await actor.transcribe(audioURL: audioURL, vocabularyHint: "")
        // Empty hint should not include a prompt field — verify body is smaller
        let body = capturedRequest?.httpBody ?? Data()
        XCTAssertFalse(String(data: body, encoding: .utf8)?.contains("prompt") ?? false)
    }
}
