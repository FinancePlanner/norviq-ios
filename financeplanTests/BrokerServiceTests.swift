import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class BrokerServiceTests: XCTestCase {
  private final class SessionMock: BrokerURLSessionProtocol {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private final class AuthSessionManagerMock: AuthSessionManaging {
    var validAccessTokenCalls = 0
    var refreshAccessTokenCalls = 0
    var logoutCalls = 0
    var invalidateSessionCalls = 0
    var validAccessTokenResult: Result<String?, Error> = .failure(MockError.notConfigured)
    var refreshAccessTokenResult: Result<String?, Error> = .failure(MockError.notConfigured)

    func restoreSessionIfNeeded() async -> Bool { false }

    func validAccessToken() async throws -> String? {
      validAccessTokenCalls += 1
      return try validAccessTokenResult.get()
    }

    func refreshAccessToken() async throws -> String? {
      refreshAccessTokenCalls += 1
      return try refreshAccessTokenResult.get()
    }

    func logout() async {
      logoutCalls += 1
    }

    func invalidateSession() async {
      invalidateSessionCalls += 1
    }
  }

  private enum MockError: Error {
    case notConfigured
  }

  func testPreviewCsvImport_UsesTextCsvRequestAndProviderQuery() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportPreviewResponse(
      provider: "ibkr",
      items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
      errors: []
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "provider" })?.value, "ibkr")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "text/csv")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "symbol,shares\nAAPL,10")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await client.previewCsvImport(
      provider: "ibkr",
      csvData: Data("symbol,shares\nAAPL,10".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testCommitCsvImport_UsesTextCsvRequestAndProviderQuery() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportCommitResponse(
      provider: "ibkr",
      inserted: [.init(id: "stock-1", symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
      updated: [],
      errors: []
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv/commit")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "provider" })?.value, "ibkr")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "text/csv")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await client.commitCsvImport(
      provider: "ibkr",
      csvData: Data("symbol,shares\nAAPL,10".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testPreviewCsvImport_WhenUnauthorized_RefreshesAndRetries() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")

    let service = BrokerService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session
    )

    var requestCount = 0
    session.handler = { request in
      requestCount += 1
      if requestCount == 1 {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
        let response = try XCTUnwrap(
          HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)
        )
        return (#"{"error":"expired"}"#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
      let payload = CsvImportPreviewResponse(provider: "ibkr", items: [], errors: [])
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder().encode(payload), response)
    }

    let response = try await service.previewCsvImport(provider: "ibkr", csvData: Data("symbol\nAAPL".utf8))
    XCTAssertEqual(response.provider, "ibkr")
    XCTAssertEqual(requestCount, 2)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 0)
  }

  func testCommitCsvImport_WhenRetryIsUnauthorized_InvalidatesSession() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")

    let service = BrokerService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session
    )

    session.handler = { request in
      let status = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)
      )
      if request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token" {
        return (#"{"error":"retry unauthorized"}"#.data(using: .utf8) ?? Data(), status)
      }
      return (#"{"error":"expired"}"#.data(using: .utf8) ?? Data(), status)
    }

    do {
      _ = try await service.commitCsvImport(provider: "ibkr", csvData: Data("symbol\nAAPL".utf8))
      XCTFail("Expected unauthorized error")
    } catch let error as BrokerHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("retry unauthorized"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 1)
  }
}
