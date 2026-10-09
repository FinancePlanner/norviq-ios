import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class TerminalPositionsHTTPClientTests: XCTestCase {
  private func makeClient(_ session: TerminalSessionMock) -> TerminalPositionsHTTPClient {
    TerminalPositionsHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )
  }

  func testListSendsTheTickerAsAQueryAndDecodesTheBackendShape() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v1/terminal-positions")
      XCTAssertEqual(
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems,
        [URLQueryItem(name: "ticker", value: "AMZN")]
      )
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      return terminalHTTPResponse(request, status: 200, json: #"{"currency":"USD","positions":[\#(TerminalJSON.position)]}"#)
    }

    let list = try await makeClient(session).list(ticker: "AMZN")

    XCTAssertEqual(list.currency, "USD")
    XCTAssertEqual(list.positions.first?.ticker, "AMZN")
    XCTAssertEqual(list.positions.first?.sharesNeeded ?? 0, 1_100, accuracy: 0.000001)
    XCTAssertNil(list.positions.first?.scenarioError)
  }

  func testListWithoutATickerSendsNoQuery() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      XCTAssertNil(request.url?.query)
      return terminalHTTPResponse(request, status: 200, json: #"{"currency":"EUR","positions":[]}"#)
    }

    let list = try await makeClient(session).list(ticker: nil)

    XCTAssertEqual(list.currency, "EUR")
    XCTAssertEqual(list.positions, [])
  }

  func testUpdateSendsAPatchWithOnlyTheSetFieldsAndClear() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "PATCH")
      XCTAssertEqual(request.url?.path, "/v1/terminal-positions/p1")
      let body = terminalJSONBody(request)
      XCTAssertEqual(body?["value_wanted"] as? Double, 2_000_000)
      XCTAssertEqual(body?["clear"] as? [String], ["notes"])
      XCTAssertEqual(body?.count, 2, "nil fields must be left out, not sent as null")
      return terminalHTTPResponse(request, status: 200, json: TerminalJSON.position)
    }
    let request = TerminalPositionUpdateRequest(
      ticker: nil, sharesOutstanding: nil, terminalShareCount: nil, terminalMarketCap: nil,
      valueWanted: 2_000_000, sharesOwned: nil, currentSharePrice: nil, notes: nil, clear: ["notes"]
    )

    _ = try await makeClient(session).update(id: "p1", request)
  }

  func testDeleteAcceptsAnEmpty204() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.url?.path, "/v1/terminal-positions/p1")
      return terminalHTTPResponse(request, status: 204)
    }

    try await makeClient(session).delete(id: "p1")
  }

  func testDuplicateAndReorderUseTheirRoutes() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      switch (request.httpMethod, request.url?.path) {
      case ("POST", "/v1/terminal-positions/p1/duplicate"):
        return terminalHTTPResponse(request, status: 201, json: TerminalJSON.position)
      case ("PUT", "/v1/terminal-positions/order"):
        XCTAssertEqual(terminalJSONBody(request)?["ids"] as? [String], ["p2", "p1"])
        return terminalHTTPResponse(request, status: 200, json: #"{"currency":"USD","positions":[]}"#)
      default:
        XCTFail("Unexpected \(request.httpMethod ?? "") \(request.url?.path ?? "")")
        return terminalHTTPResponse(request, status: 500)
      }
    }
    let client = makeClient(session)

    _ = try await client.duplicate(id: "p1")
    _ = try await client.reorder(ids: ["p2", "p1"])
  }

  func testScenarioSuggestionOmitsAMissingHorizon() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/terminal-positions/ai/scenario")
      let body = terminalJSONBody(request)
      XCTAssertEqual(body?["ticker"] as? String, "AMZN")
      XCTAssertNil(body?["horizon_years"])
      return terminalHTTPResponse(request, status: 200, json: """
      {"ticker":"AMZN","terminalShareCount":11000000000,"terminalMarketCap":10000000000000,\
      "horizonYears":10,"rationale":"Cloud and ads keep compounding.","sources":["https://example.com/a"]}
      """)
    }

    let suggestion = try await makeClient(session).suggestScenario(ticker: "AMZN", horizonYears: nil)

    XCTAssertEqual(suggestion.horizonYears, 10)
  }

  func testUpgradeRequiredBodyBecomesUpgradeRequired() async {
    let session = TerminalSessionMock()
    session.handler = { request in
      terminalHTTPResponse(request, status: 403, json: """
      {"success":false,"code":"upgrade_required","error":"Upgrade required. feature=terminal_position_ai plan=free required=pro",\
      "feature":"terminal_position_ai","plan":"free","requiredPlan":"pro"}
      """)
    }

    do {
      _ = try await makeClient(session).shareFacts(ticker: "AMZN")
      XCTFail("Expected an upgrade error")
    } catch {
      XCTAssertEqual(error as? TerminalPositionsHTTPClient.Error, .upgradeRequired(feature: "terminal_position_ai"))
    }
  }

  func testPlainForbiddenStaysRejected() async {
    let session = TerminalSessionMock()
    session.handler = { request in
      terminalHTTPResponse(request, status: 403, json: #"{"error":true,"reason":"Missing scope planning:read"}"#)
    }

    do {
      _ = try await makeClient(session).shareFacts(ticker: "AMZN")
      XCTFail("Expected a rejection")
    } catch {
      XCTAssertEqual(
        error as? TerminalPositionsHTTPClient.Error,
        .rejected(status: 403, message: "Missing scope planning:read")
      )
    }
  }

  func testAIUnavailableKeepsTheStatus() async {
    let session = TerminalSessionMock()
    session.handler = { request in
      terminalHTTPResponse(request, status: 503, json: #"{"error":true,"reason":"AI lookup unavailable"}"#)
    }

    do {
      _ = try await makeClient(session).shareFacts(ticker: "AMZN")
      XCTFail("Expected a rejection")
    } catch {
      XCTAssertEqual(error as? TerminalPositionsHTTPClient.Error, .rejected(status: 503, message: "AI lookup unavailable"))
    }
  }
}
