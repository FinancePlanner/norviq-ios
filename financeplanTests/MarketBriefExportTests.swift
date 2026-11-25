import Foundation
import StockPlanShared
import UIKit
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

  @MainActor
  func testServiceSendsBriefLanguage() async throws {
    let session = SessionMock()
    let queries = LockedBox<[String]>([])
    let json = #"{"editionId":"MI-2026-11-25-O","revision":1,"rendererVersion":1,"formats":[]}"#
    respond(session, body: Data(json.utf8)) { request in
      queries.value.append(request.url?.query ?? "")
    }
    let service = DefaultMarketBriefExportService(environmentManager: AppEnvironmentManager(), session: session)
    let payload = try payload(language: "pt-PT")

    _ = try await service.manifest(for: payload)
    _ = try await service.file(.pdf, query: "rev=1&v=1", for: payload)

    XCTAssertEqual(queries.value.count, 2)
    for query in queries.value {
      XCTAssertTrue(query.contains("lang=pt-PT"), query)
    }
  }
}

@MainActor
final class MarketBriefExportStudioModelTests: XCTestCase {
  private var root: URL!
  private var pauses = LockedBox<[Duration]>([])

  override func setUp() async throws {
    root = FileManager.default.temporaryDirectory.appending(path: "export-studio-tests-\(UUID().uuidString)")
    pauses = LockedBox([])
  }

  override func tearDown() async throws {
    try? FileManager.default.removeItem(at: root)
  }

  private func payload(language: String = "en") throws -> MarketBriefSharePayload {
    let brief = MarketBriefResponse(
      enabled: true,
      tradingDate: "2026-11-25",
      slot: .morning,
      language: language,
      greeting: nil,
      groups: [],
      items: [MarketBriefItem(kind: .highlight, text: "Chip stocks lead futures.", tickers: ["NVDA"], sourceUrl: nil)],
      generatedAt: "2026-11-25T07:16:00Z",
      degraded: false
    )
    return try XCTUnwrap(MarketBriefSharePayload(brief: brief))
  }

  private func manifest(revision: Int = 1, pdfPages: Int? = nil) -> MarketBriefExportManifest {
    let query = "rev=\(revision)&v=1"
    return MarketBriefExportManifest(
      editionId: "MI-2026-11-25-O",
      revision: revision,
      rendererVersion: 1,
      formats: [
        MarketBriefExportFormatInfo(id: "social", width: 1080, height: 1350, mime: "image/png", query: query),
        MarketBriefExportFormatInfo(id: "story", width: 1080, height: 1920, mime: "image/png", query: query),
        MarketBriefExportFormatInfo(id: "pdf", pages: pdfPages, mime: "application/pdf", query: query),
        MarketBriefExportFormatInfo(id: "og", width: 1200, height: 630, mime: "image/png", query: query)
      ]
    )
  }

  private func png(_ name: String) -> MarketBriefExportFile {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
      UIColor.systemTeal.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }
    return MarketBriefExportFile(data: image.pngData() ?? Data(), fileName: name, mime: "image/png")
  }

  private func pdf(pages: Int) -> MarketBriefExportFile {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
    let data = renderer.pdfData { context in
      for page in 0..<pages {
        context.beginPage()
        ("Page \(page + 1)" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: nil)
      }
    }
    return MarketBriefExportFile(data: data, fileName: "norviq-MI-2026-11-25-O-en.pdf", mime: "application/pdf")
  }

  private func makeModel(_ service: ExportServiceFake, language: String = "en") throws -> MarketBriefExportStudioModel {
    let pauses = pauses
    return MarketBriefExportStudioModel(
      payload: try payload(language: language),
      service: service,
      store: MarketBriefExportFileStore(root: root),
      pause: { pauses.value.append($0) }
    )
  }

  private func ready(_ state: MarketBriefExportState, file: StaticString = #filePath, line: UInt = #line) throws -> MarketBriefExportReady {
    guard case let .ready(ready) = state else {
      XCTFail("expected .ready, got \(state)", file: file, line: line)
      throw CancellationError()
    }
    return ready
  }

  private static let busy = MarketBriefHTTPClient.Error.invalidStatus(503)
  private static let gone = MarketBriefHTTPClient.Error.invalidStatus(404)

  func testLoadsOnlyTheRequestedFormat() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest())]
    service.files[.story] = [.success(png("norviq-MI-2026-11-25-O-story-en.png"))]
    let model = try makeModel(service)

    await model.load(.story)

    XCTAssertEqual(service.manifestCalls, 1)
    XCTAssertEqual(service.fileCalls, [.init(format: .story, query: "rev=1&v=1")])
    XCTAssertEqual(model.state(for: .social), .idle)
    XCTAssertEqual(model.state(for: .pdf), .idle)
    let ready = try ready(model.state(for: .story))
    XCTAssertFalse(ready.isNativeFallback)
    XCTAssertNotNil(ready.preview)
    XCTAssertNil(ready.pages)
    XCTAssertEqual(
      ready.fileURL,
      root.appending(path: "MI-2026-11-25-O-r1/norviq-MI-2026-11-25-O-story-en.png")
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: ready.fileURL.path))
    XCTAssertEqual(MarketBriefStudioTab.allCases, [.social, .story, .pdf, .link])
    XCTAssertEqual(MarketBriefStudioTab.story.format, .story)
    XCTAssertNil(MarketBriefStudioTab.link.format)
  }

  func testBusyRendererRetriesOnce() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest())]
    service.files[.story] = [.failure(Self.busy), .success(png("norviq-MI-2026-11-25-O-story-en.png"))]
    let model = try makeModel(service)

    await model.load(.story)

    _ = try ready(model.state(for: .story))
    XCTAssertEqual(service.fileCalls.count, 2)
    XCTAssertEqual(pauses.value, [.seconds(2)])

    let stillBusy = ExportServiceFake()
    stillBusy.manifests = [.success(manifest())]
    stillBusy.files[.story] = [.failure(MarketBriefHTTPClient.Error.invalidStatus(500)), .failure(Self.busy)]
    pauses.value = []
    let failing = try makeModel(stillBusy)

    await failing.load(.story)

    XCTAssertEqual(failing.state(for: .story), .unavailable)
    XCTAssertEqual(stillBusy.fileCalls.count, 2)
    XCTAssertEqual(stillBusy.manifestCalls, 1)
    XCTAssertEqual(pauses.value, [.seconds(2)])
  }

  func testSupersededFileRefetchesManifestOnce() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest(revision: 1)), .success(manifest(revision: 2))]
    service.files[.social] = [.failure(Self.gone), .success(png("norviq-MI-2026-11-25-O-social-en.png"))]
    let model = try makeModel(service)

    await model.load(.social)

    let ready = try ready(model.state(for: .social))
    XCTAssertFalse(ready.isNativeFallback)
    XCTAssertEqual(service.manifestCalls, 2)
    XCTAssertEqual(
      service.fileCalls,
      [.init(format: .social, query: "rev=1&v=1"), .init(format: .social, query: "rev=2&v=1")]
    )
    XCTAssertEqual(ready.fileURL.deletingLastPathComponent().lastPathComponent, "MI-2026-11-25-O-r2")
    XCTAssertEqual(pauses.value, [])
  }

  func testUnauthorizedNeverFallsBack() async throws {
    let service = ExportServiceFake()
    service.manifests = [.failure(MarketBriefHTTPClient.Error.unauthorized("Your session expired. Sign in again."))]
    let model = try makeModel(service)

    await model.load(.social)

    XCTAssertEqual(model.state(for: .social), .unauthorized("Your session expired. Sign in again."))
    XCTAssertEqual(service.manifestCalls, 1)
    XCTAssertEqual(service.fileCalls, [])
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "native").path))

    let fileExpired = ExportServiceFake()
    fileExpired.manifests = [.success(manifest())]
    fileExpired.files[.social] = [.failure(MarketBriefHTTPClient.Error.unauthorized(nil))]
    let other = try makeModel(fileExpired)

    await other.load(.social)

    XCTAssertEqual(other.state(for: .social), .unauthorized("Your session expired."))
    XCTAssertEqual(fileExpired.fileCalls.count, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "native").path))
  }

  func testSocialFallsBackToNativeCardWhenUnavailable() async throws {
    let service = ExportServiceFake()
    service.manifests = [.failure(Self.busy)]
    let model = try makeModel(service, language: "pt-PT")

    await model.load(.social)
    await model.load(.story)

    XCTAssertEqual(service.fileCalls, [])
    XCTAssertEqual(model.state(for: .story), .unavailable)
    let ready = try ready(model.state(for: .social))
    XCTAssertTrue(ready.isNativeFallback)
    XCTAssertNotNil(ready.preview)
    XCTAssertEqual(
      ready.fileURL,
      root.appending(path: "native/norviq-brief-2026-11-25-morning-social-pt-PT.png")
    )
    let data = try Data(contentsOf: ready.fileURL)
    XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
    XCTAssertEqual(image.width, 1080)
    XCTAssertEqual(image.height, 1350)
  }

  func testFileStoreNamesPerRevision() throws {
    let store = MarketBriefExportFileStore(root: root)
    let first = MarketBriefExportFile(data: Data([1]), fileName: "norviq-MI-2026-11-25-O-social-pt-PT.png", mime: "image/png")
    let replacement = MarketBriefExportFile(data: Data([2]), fileName: first.fileName, mime: "image/png")

    let r1 = try store.url(for: first, editionId: "MI-2026-11-25-O", revision: 1)
    let r2 = try store.url(for: first, editionId: "MI-2026-11-25-O", revision: 2)
    let again = try store.url(for: replacement, editionId: "MI-2026-11-25-O", revision: 1)

    XCTAssertNotEqual(r1, r2)
    XCTAssertEqual(r1, root.appending(path: "MI-2026-11-25-O-r1/norviq-MI-2026-11-25-O-social-pt-PT.png"))
    XCTAssertEqual(r2, root.appending(path: "MI-2026-11-25-O-r2/norviq-MI-2026-11-25-O-social-pt-PT.png"))
    XCTAssertTrue(r1.lastPathComponent.hasSuffix("-pt-PT.png"))
    XCTAssertEqual(again, r1)
    XCTAssertEqual(try Data(contentsOf: r1), Data([1]), "an existing file is reused, not rewritten")
  }

  func testPDFReadyHasThumbnailAndManifestPages() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest(pdfPages: 3))]
    service.files[.pdf] = [.success(pdf(pages: 2))]
    let model = try makeModel(service)

    await model.load(.pdf)

    let ready = try ready(model.state(for: .pdf))
    XCTAssertEqual(ready.pages, 3)
    XCTAssertNotNil(ready.preview)
    XCTAssertFalse(ready.isNativeFallback)
    XCTAssertEqual(ready.fileURL.pathExtension, "pdf")

    let noPages = ExportServiceFake()
    noPages.manifests = [.success(manifest(pdfPages: nil))]
    noPages.files[.pdf] = [.success(pdf(pages: 2))]
    try? FileManager.default.removeItem(at: root)
    let counted = try makeModel(noPages)

    await counted.load(.pdf)

    XCTAssertEqual(try self.ready(counted.state(for: .pdf)).pages, 2)
  }

  func testLoadIsIdempotentWhileLoadingOrReady() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest(pdfPages: 1))]
    service.files[.pdf] = [.success(pdf(pages: 1))]
    let model = try makeModel(service)

    async let first: Void = model.load(.pdf)
    async let second: Void = model.load(.pdf)
    _ = await (first, second)
    await model.load(.pdf)

    _ = try ready(model.state(for: .pdf))
    XCTAssertEqual(service.fileCalls.count, 1)
    XCTAssertEqual(service.manifestCalls, 1)
  }

  func testCancelledCallerDoesNotStrandTheLoad() async throws {
    let service = ExportServiceFake()
    service.holdsManifest = true
    service.manifests = [.success(manifest())]
    service.files[.social] = [.success(png("norviq-MI-2026-11-25-O-social-en.png"))]
    let model = try makeModel(service)

    let first = Task { await model.load(.social) }
    while service.manifestGate == nil { await Task.yield() }
    first.cancel()
    // The tab shows again while the first load is still in flight: a no-op.
    await model.load(.social)
    XCTAssertEqual(model.state(for: .social), .loading)
    service.releaseManifest()
    await first.value

    let ready = try ready(model.state(for: .social))
    XCTAssertFalse(ready.isNativeFallback)
    XCTAssertEqual(service.fileCalls.count, 1)
    XCTAssertEqual(service.manifestCalls, 1)
  }

  func testRetryLoadsAgainAfterFailure() async throws {
    let service = ExportServiceFake()
    service.manifests = [.success(manifest())]
    service.files[.story] = [.failure(Self.busy), .failure(Self.busy), .success(png("norviq-MI-2026-11-25-O-story-en.png"))]
    let model = try makeModel(service)

    await model.load(.story)
    XCTAssertEqual(model.state(for: .story), .unavailable)
    XCTAssertEqual(service.fileCalls.count, 2)

    await model.retry(.story)

    _ = try ready(model.state(for: .story))
    XCTAssertEqual(service.fileCalls.count, 3)
    XCTAssertEqual(service.manifestCalls, 1, "the manifest in memory is reused")
  }
}

/// Scripted responses, consumed in order; the last one repeats.
private final class ExportServiceFake: MarketBriefExportServicing, @unchecked Sendable {
  struct FileCall: Equatable {
    let format: MarketBriefExportFormat
    let query: String
  }

  var manifests: [Result<MarketBriefExportManifest, Error>] = []
  var files: [MarketBriefExportFormat: [Result<MarketBriefExportFile, Error>]] = [:]
  private(set) var manifestCalls = 0
  private(set) var fileCalls: [FileCall] = []
  /// When set, `manifest` waits for `releaseManifest()`.
  var holdsManifest = false
  private(set) var manifestGate: CheckedContinuation<Void, Never>?

  func manifest(for payload: MarketBriefSharePayload) async throws -> MarketBriefExportManifest {
    manifestCalls += 1
    if holdsManifest {
      await withCheckedContinuation { manifestGate = $0 }
    }
    await Task.yield()
    return try Self.next(&manifests).get()
  }

  func file(
    _ format: MarketBriefExportFormat,
    query: String,
    for payload: MarketBriefSharePayload
  ) async throws -> MarketBriefExportFile {
    // As URLSession does: a cancelled caller's request fails.
    try Task.checkCancellation()
    fileCalls.append(FileCall(format: format, query: query))
    await Task.yield()
    var queue = files[format] ?? []
    defer { files[format] = queue }
    return try Self.next(&queue).get()
  }

  func releaseManifest() {
    holdsManifest = false
    manifestGate?.resume()
    manifestGate = nil
  }

  private static func next<T>(_ queue: inout [Result<T, Error>]) -> Result<T, Error> {
    guard let first = queue.first else { return .failure(MarketBriefHTTPClient.Error.invalidStatus(404)) }
    if queue.count > 1 { queue.removeFirst() }
    return first
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
