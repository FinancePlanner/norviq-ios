import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            fatalError("MockURLProtocol.handler must be set before use")
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class InsightsHTTPClientTests: XCTestCase {
    nonisolated(unsafe) private var session: URLSession!
    nonisolated(unsafe) private var client: InsightsHTTPClient!

    override func setUp() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = InsightsHTTPClient(baseURL: URL(string: "https://api.example.com")!, session: session)
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        session = nil
        client = nil
    }

    func testGetTickerSentimentDecodesAggregateAndPosts() async throws {
        let json = """
        {
          "symbol": "AMD",
          "windowDays": 14,
          "aggregate": { "label": "bullish", "score": 0.42, "postCount": 2 },
          "posts": [
            { "author": "Notable", "authorHandle": "notable", "text": "AMD undervalued on AI demand.",
              "url": "https://x.com/notable/status/1", "sentimentLabel": "bullish",
              "sentimentScore": 0.8, "confidence": 0.9, "postedAt": "2026-07-16T10:00:00Z" },
            { "author": null, "authorHandle": null, "text": "Cautious on valuation.",
              "url": null, "sentimentLabel": "bearish",
              "sentimentScore": -0.3, "confidence": null, "postedAt": "2026-07-15T09:00:00Z" }
          ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.contains("/v1/insights/tickers/AMD/sentiment") == true)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json, response)
        }

        let result = try await client.getTickerSentiment(symbol: "AMD")

        XCTAssertEqual(result.symbol, "AMD")
        XCTAssertEqual(result.windowDays, 14)
        XCTAssertEqual(result.aggregate.label, "bullish")
        XCTAssertEqual(result.aggregate.postCount, 2)
        XCTAssertEqual(result.posts.count, 2)
        XCTAssertEqual(result.posts.first?.authorHandle, "notable")
        XCTAssertEqual(result.posts.first?.sentimentLabel, "bullish")
        XCTAssertNil(result.posts.last?.author)
        XCTAssertNil(result.posts.last?.url)
    }
}
