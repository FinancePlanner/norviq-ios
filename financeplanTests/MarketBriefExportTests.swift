import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

final class MarketBriefExportEndpointTests: XCTestCase {
  // Nonisolated: BaseHTTPClient sends requests from a @concurrent context.
  nonisolated private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: (@Sendable (URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else { fatalError("SessionMock.handler must be configured before use") }
      return try handler(request)
    }
  }

  private let baseURL = URL(string: "https://api.example.com")!

  private func queryItems(_ request: URLRequest) -> [String: String] {
    let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }

  private func payload(language: String, slot: MarketBriefSlot = .morning) throws -> MarketBriefSharePayload {
    let brief = MarketBriefResponse(
      enabled: true,
      tradingDate: "2026-11-25",
      slot: slot,
      language: language,
      greeting: nil,
      groups: [],
      items: [],
      generatedAt: "2026-11-25T07:16:00Z",
      degraded: false
    )
    return try XCTUnwrap(MarketBriefSharePayload(brief: brief))
  }

  private func respond(
    _ session: SessionMock,
    status: Int = 200,
    body: Data = Data(),
    headers: [String: String]? = nil,
    inspect: (@Sendable (URLRequest) -> Void)? = nil
  ) {
    session.handler = { request in
      inspect?(request)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: headers)
      )
      return (body, response)
    }
  }

  func testExportsEndpointRoutes() async throws {
    let client = BaseHTTPClient(baseURL: baseURL)

    let request = try await client.makeURLRequest(
      for: GetMarketBriefExportsEndpoint(lang: "pt-PT", slot: .evening, date: "2026-11-25")
    )

    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url?.path, "/v1/market/brief/exports")
    XCTAssertEqual(queryItems(request), ["lang": "pt-PT", "slot": "evening", "date": "2026-11-25"])
  }

  func testFileEndpointSendsRevAndVFromQueryVerbatim() async throws {
    let client = BaseHTTPClient(baseURL: baseURL)

    let request = try await client.makeURLRequest(
      for: GetMarketBriefExportFileEndpoint(
        lang: "en", slot: .morning, date: "2026-11-25", format: .story, query: "rev=2&v=1"
      )
    )

    XCTAssertEqual(request.url?.path, "/v1/market/brief/export")
    XCTAssertEqual(
      queryItems(request),
      ["lang": "en", "slot": "morning", "date": "2026-11-25", "format": "story", "rev": "2", "v": "1"]
    )
    XCTAssertEqual(GetMarketBriefExportFileEndpoint.timeout, 30)
  }

  func testFileEndpointDropsMalformedQuery() async throws {
    let client = BaseHTTPClient(baseURL: baseURL)

    for query in ["rev=2&v=1&x=1", "", "rev=a&v=1", "v=1&rev=2", "rev=2&v=1\n"] {
      let request = try await client.makeURLRequest(
        for: GetMarketBriefExportFileEndpoint(
          lang: "en", slot: .morning, date: "2026-11-25", format: .pdf, query: query
        )
      )
      let items = queryItems(request)
      XCTAssertNil(items["rev"], "query \(query.debugDescription)")
      XCTAssertNil(items["v"], "query \(query.debugDescription)")
      XCTAssertEqual(items["format"], "pdf")
    }
  }

  func testExportFileUsesBriefLanguage() async throws {
    let session = SessionMock()
    respond(
      session,
      body: Data([0x89, 0x50]),
      headers: [
        "Content-Disposition": #"inline; filename="norviq-MI-2026-11-25-O-social-pt-PT.png""#,
        "Content-Type": "image/png"
      ]
    ) { request in
      XCTAssertEqual(request.timeoutInterval, 30)
      XCTAssertEqual(request.url?.path, "/v1/market/brief/export")
    }
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)
    let payload = try payload(language: "pt-PT")

    let file = try await client.exportFile(
      lang: payload.languageCode, slot: payload.slot, date: payload.tradingDate, format: .social, query: "rev=1&v=1"
    )

    XCTAssertEqual(payload.languageCode, "pt-PT")
    XCTAssertEqual(file.fileName, "norviq-MI-2026-11-25-O-social-pt-PT.png")
    XCTAssertEqual(file.mime, "image/png")
    XCTAssertEqual(file.data, Data([0x89, 0x50]))
  }

  func testRequestCarriesBriefLanguage() async throws {
    let session = SessionMock()
    let seen = LockedBox<String?>(nil)
    respond(session) { request in seen.value = request.url?.query }
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)

    _ = try await client.exportFile(lang: "pt-PT", slot: .morning, date: "2026-11-25", format: .social, query: "")

    XCTAssertTrue(try XCTUnwrap(seen.value).contains("lang=pt-PT"))
  }

  func testExportFileFallbackNameWithoutContentDisposition() async throws {
    let session = SessionMock()
    respond(session, body: Data([1]))
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)

    let file = try await client.exportFile(lang: "en", slot: .morning, date: "2026-11-25", format: .pdf, query: "")

    XCTAssertEqual(file.fileName, "norviq-brief-2026-11-25-morning-pdf-en.pdf")
    XCTAssertEqual(file.mime, "application/pdf")
  }

  func testUnsafeContentDispositionFallsBackToGeneratedName() async throws {
    let session = SessionMock()
    respond(session, body: Data([1]), headers: ["Content-Disposition": #"inline; filename="../../evil.png""#])
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)

    let file = try await client.exportFile(lang: "en", slot: .evening, date: "2026-11-25", format: .story, query: "")

    XCTAssertEqual(file.fileName, "norviq-brief-2026-11-25-evening-story-en.png")
  }

  func testManifestDecodes() async throws {
    let session = SessionMock()
    let json = #"""
    {"editionId":"MI-2026-11-25-O","revision":2,"rendererVersion":1,
     "formats":[{"id":"social","width":1200,"height":630,"mime":"image/png","query":"rev=2&v=1"}]}
    """#
    respond(session, body: Data(json.utf8))
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)

    let manifest = try await client.exports(lang: "en", slot: .morning, date: "2026-11-25")

    XCTAssertEqual(manifest.revision, 2)
    XCTAssertEqual(manifest.format("social")?.query, "rev=2&v=1")
  }

  func testStatusesStayDistinguishable() async throws {
    for code in [404, 500, 503] {
      let session = SessionMock()
      respond(session, status: code, body: Data(#"{"error":"renderer busy"}"#.utf8))
      let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)
      do {
        _ = try await client.exportFile(lang: "en", slot: .morning, date: "2026-11-25", format: .social, query: "")
        XCTFail("expected \(code) to throw")
      } catch let error as MarketBriefHTTPClient.Error {
        XCTAssertEqual(error, .invalidStatus(code))
        XCTAssertEqual(error.statusCode, code)
      }
    }

    let session = SessionMock()
    respond(session, status: 401, body: Data(#"{"error":"expired"}"#.utf8))
    let client = MarketBriefHTTPClient(baseURL: baseURL, session: session)
    do {
      _ = try await client.exportFile(lang: "en", slot: .morning, date: "2026-11-25", format: .social, query: "")
      XCTFail("expected 401 to throw")
    } catch let error as MarketBriefHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("expired"))
    }
  }
}

nonisolated private final class LockedBox<T: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: T
  init(_ value: T) { stored = value }
  var value: T {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}
