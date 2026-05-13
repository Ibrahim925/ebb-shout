import XCTest
@testable import EbbShout

final class OllamaClientTests: XCTestCase {
    var client: OllamaClient!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = OllamaClient(baseURL: URL(string: "http://localhost:11434")!, session: session)
    }

    func testEnhance_returnsResponse() async throws {
        MockURLProtocol.handler = { _ in
            let body = #"{"response":"Cleaned text."}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: URL(string: "http://localhost:11434")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        let result = try await client.enhance(transcript: "uh yeah so", systemPrompt: "clean it")
        XCTAssertEqual(result, "Cleaned text.")
    }

    func testEnhance_stripsWhitespace() async throws {
        MockURLProtocol.handler = { _ in
            let body = #"{"response":"  Cleaned text.  \n"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: URL(string: "http://localhost:11434")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        let result = try await client.enhance(transcript: "test", systemPrompt: "clean")
        XCTAssertEqual(result, "Cleaned text.")
    }
}

// MARK: - MockURLProtocol
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
