import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class PilotsMockURLProtocol: URLProtocol {
  struct Recorded {
    let request: URLRequest
    let body: Data?
  }

  /// Returns (status, JSON body) for a request.
  nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
  nonisolated(unsafe) static var recorded: [Recorded] = []

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.recorded.append(Recorded(request: request, body: Self.readBody(of: request)))
    guard let handler = Self.handler, let url = request.url else {
      fatalError("PilotsMockURLProtocol.handler must be set before use")
    }
    let (status, body) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
      fatalError("Could not build HTTPURLResponse")
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func readBody(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
    }
    return data
  }
}

private let followJSON = #"""
{"id":"11111111-1111-1111-1111-111111111111",
 "pilot":{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":12},
 "targetKind":"portfolio","portfolioListId":"22222222-2222-2222-2222-222222222222","watchlistListId":null,
 "startingCapital":10000,"currency":"USD","status":"active","appliedVersion":3,"createdAt":"2026-10-01T09:00:00Z"}
"""#

@MainActor
final class PilotsHTTPClientTests: XCTestCase {
  nonisolated(unsafe) private var client: PilotsHTTPClient!

  override func setUp() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PilotsMockURLProtocol.self]
    PilotsMockURLProtocol.recorded = []
    client = PilotsHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: URLSession(configuration: config),
      authTokenProvider: { "token" }
    )
  }

  override func tearDown() async throws {
    PilotsMockURLProtocol.handler = nil
    PilotsMockURLProtocol.recorded = []
    client = nil
  }

  private var lastRequest: URLRequest? { PilotsMockURLProtocol.recorded.last?.request }

  func testListPilotsDecodesSummariesWithBearerToken() async throws {
    PilotsMockURLProtocol.handler = { _ in
      (200, #"[{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":12},{"slug":"berkshire","displayName":"Berkshire Hathaway","kind":"fund","chamber":null,"updatedAt":null,"holdingsCount":0}]"#)
    }

    let pilots = try await client.pilots()

    XCTAssertEqual(pilots.map(\.slug), ["nancy-pelosi", "berkshire"])
    XCTAssertEqual(pilots.last?.kind, .fund)
    XCTAssertEqual(pilots.last?.holdingsCount, 0)
    XCTAssertEqual(lastRequest?.httpMethod, "GET")
    XCTAssertEqual(lastRequest?.url?.path, "/v1/pilots")
    XCTAssertEqual(lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
  }

  func testFeatureOffKeepsThe404SoCallersCanHideEntryPoints() async {
    PilotsMockURLProtocol.handler = { _ in (404, #"{"error":true,"code":"not_found","reason":"Not Found"}"#) }

    do {
      _ = try await client.pilots()
      XCTFail("Expected a 404")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 404, message: "Not Found"))
      XCTAssertEqual(error.statusCode, 404)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpgradeRequiredReadsTheFeatureFromTheBillingBody() async {
    PilotsMockURLProtocol.handler = { _ in
      (403, #"{"success":false,"code":"upgrade_required","error":"Upgrade required. feature=pilot_follows plan=free required=pro","feature":"pilot_follows","plan":"free","requiredPlan":"pro","limit":null,"current":null}"#)
    }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: nil, startingCapital: nil)

    do {
      _ = try await client.follow(request, idempotencyKey: "k")
      XCTFail("Expected a 403")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .upgradeRequired(feature: "pilot_follows", message: "Upgrade required. feature=pilot_follows plan=free required=pro"))
      XCTAssertEqual(error.statusCode, 403)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testA403WithoutTheBillingBodyIsNotReadAsAnUpgrade() async {
    // Only the structured billing body (code + feature) means "upgrade";
    // the reason text is never parsed.
    PilotsMockURLProtocol.handler = { _ in
      (403, #"{"error":true,"code":"forbidden","reason":"Upgrade required. feature=pilot_follows plan=free"}"#)
    }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: nil, startingCapital: nil)

    do {
      _ = try await client.follow(request, idempotencyKey: "k")
      XCTFail("Expected a 403")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 403, message: "Upgrade required. feature=pilot_follows plan=free"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testNonEmptyTargetKeepsThe422Reason() async {
    PilotsMockURLProtocol.handler = { _ in (422, #"{"error":true,"code":"unprocessable_entity","reason":"Choose an empty watchlist, or let Norviq create one."}"#) }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: "33333333-3333-3333-3333-333333333333", startingCapital: nil)

    do {
      _ = try await client.follow(request, idempotencyKey: "k")
      XCTFail("Expected a 422")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 422, message: "Choose an empty watchlist, or let Norviq create one."))
      XCTAssertEqual(error.errorDescription, "Choose an empty watchlist, or let Norviq create one.")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFollowPostsTheRequestWithAnIdempotencyKey() async throws {
    PilotsMockURLProtocol.handler = { _ in (201, followJSON) }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .portfolio, portfolioListId: nil, watchlistListId: nil, startingCapital: 10_000)

    let follow = try await client.follow(request, idempotencyKey: "key-1")

    XCTAssertEqual(follow.id, "11111111-1111-1111-1111-111111111111")
    XCTAssertEqual(follow.appliedVersion, 3)
    let sent = try XCTUnwrap(PilotsMockURLProtocol.recorded.last)
    XCTAssertEqual(sent.request.httpMethod, "POST")
    XCTAssertEqual(sent.request.url?.path, "/v1/pilot-follows")
    // If this fails, the `headers` declaration in PilotsEndpoints does not match
    // AnyAPI's `Endpoint.headers` requirement. Copy `StockEnpoints.swift:398` exactly.
    XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Idempotency-Key"), "key-1")
    let body = try XCTUnwrap(sent.body)
    XCTAssertEqual(try JSONDecoder.stockPlanShared.decode(PilotFollowCreateRequest.self, from: body), request)
  }

  func testPauseSendsPatchWithTheNewStatus() async throws {
    PilotsMockURLProtocol.handler = { _ in (200, followJSON.replacingOccurrences(of: #""status":"active""#, with: #""status":"paused""#)) }

    let follow = try await client.setStatus(.paused, followId: "11111111-1111-1111-1111-111111111111")

    XCTAssertEqual(follow.status, .paused)
    let sent = try XCTUnwrap(PilotsMockURLProtocol.recorded.last)
    XCTAssertEqual(sent.request.httpMethod, "PATCH")
    XCTAssertEqual(sent.request.url?.path, "/v1/pilot-follows/11111111-1111-1111-1111-111111111111")
    let body = try XCTUnwrap(sent.body)
    XCTAssertEqual(try JSONDecoder.stockPlanShared.decode(PilotFollowUpdateRequest.self, from: body).status, .paused)
  }

  func testStopSendsDeleteAndAcceptsANoContentResponse() async throws {
    PilotsMockURLProtocol.handler = { _ in (204, "") }

    try await client.stopFollowing(followId: "11111111-1111-1111-1111-111111111111")

    XCTAssertEqual(lastRequest?.httpMethod, "DELETE")
    XCTAssertEqual(lastRequest?.url?.path, "/v1/pilot-follows/11111111-1111-1111-1111-111111111111")
  }

  func testEventsAndSnapshotsDecodeFromTheirOwnPaths() async throws {
    PilotsMockURLProtocol.handler = { request in
      if request.url?.path.hasSuffix("/events") == true {
        return (200, #"[{"id":"e1","bookVersion":3,"kind":"buy","symbol":"NVDA","quantity":12.5,"price":123.45,"pricedAt":"2026-09-30T14:00:00Z","note":"Pelosi bought 2026-09-14"}]"#)
      }
      return (200, #"[{"date":"2026-09-30","value":10000,"cash":120.5},{"date":"2026-10-01","value":10420,"cash":120.5}]"#)
    }

    let events = try await client.events(followId: "f1")
    let snapshots = try await client.snapshots(followId: "f1")

    XCTAssertEqual(events.first?.kind, "buy")
    XCTAssertEqual(events.first?.quantity, 12.5)
    XCTAssertEqual(snapshots.map(\.date), ["2026-09-30", "2026-10-01"])
    XCTAssertEqual(PilotsMockURLProtocol.recorded.map { $0.request.url?.path }, ["/v1/pilot-follows/f1/events", "/v1/pilot-follows/f1/snapshots"])
  }
}
