import XCTest
@testable import EbbShout

final class EnhancementActorTests: XCTestCase {
    func makeActor(responseText: String = "Enhanced.") -> EnhancementActor {
        MockURLProtocol.handler = { req in
            let body = "{\"response\":\"\(responseText)\"}".data(using: .utf8)!
            let res = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (res, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OllamaClient(baseURL: URL(string: "http://localhost:11434")!,
                                   session: URLSession(configuration: config))
        return EnhancementActor(ollamaClient: client)
    }

    func testEnhanceCasual() async throws {
        let actor = makeActor()
        let result = try await actor.enhance(transcript: "um yeah", mode: .casual, styleContext: nil)
        XCTAssertEqual(result, "Enhanced.")
    }

    func testEnhanceFormal() async throws {
        let actor = makeActor()
        let result = try await actor.enhance(transcript: "um yeah", mode: .formal, styleContext: "Professional tone.")
        XCTAssertEqual(result, "Enhanced.")
    }

    func testEnhanceRegular() async throws {
        let actor = makeActor()
        let result = try await actor.enhance(transcript: "uh so like", mode: .regular, styleContext: nil)
        XCTAssertEqual(result, "Enhanced.")
    }
}
