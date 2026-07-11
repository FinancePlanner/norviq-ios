import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class BrokerServiceTests: XCTestCase {
  @MainActor
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private final class WebAuthenticatorMock: OAuthWebAuthenticating, @unchecked Sendable {
    var result: Result<URL, Error> = .failure(MockError.notConfigured)

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
      try result.get()
    }
  }

  private final class AuthSessionManagerMock: AuthSessionManaging, @unchecked Sendable {
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

  func testStartIBKRConnect_UsesBrokerStartEndpoint() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = BrokerConnectStartResponse(
      flowId: UUID().uuidString,
      authorizationURL: "https://api.example.com/v1/auth/brokers/ibkr/callback?flowId=1&state=abc",
      expiresIn: 600
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/brokers/ibkr/connect/start")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await client.startIBKRConnect(
      redirectURI: "norviqa://oauth/broker-callback",
      portfolioListId: "portfolio-1"
    )

    XCTAssertEqual(response, expected)
  }

  func testPreviewCsvImport_UsesMultipartRequestAndProviderQuery() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportPreviewResponse(
      provider: "generic",
      items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
      errors: []
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "provider" })?.value, "generic")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "portfolioListId" })?.value, "portfolio-1")
      let contentType = request.value(forHTTPHeaderField: "Content-Type")
      XCTAssertNotNil(contentType)
      XCTAssertTrue(contentType?.starts(with: "multipart/form-data; boundary=") == true)
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
      XCTAssertTrue(bodyString.contains("name=\"provider\""))
      XCTAssertTrue(bodyString.contains("generic"))
      XCTAssertTrue(bodyString.contains("name=\"file\"; filename=\"portfolio-import.csv\""))
      XCTAssertTrue(bodyString.contains("Content-Type: text/csv"))
      XCTAssertTrue(bodyString.contains("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding"))

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
      provider: "generic",
      portfolioListId: "portfolio-1",
      csvData: Data("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testCommitCsvImport_UsesMultipartRequestAndProviderQuery() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportCommitResponse(
      provider: "generic",
      inserted: [.init(id: "stock-1", symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil, createdAt: "2026-01-10T00:00:00Z")],
      updated: [],
      errors: []
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv/commit")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "provider" })?.value, "generic")
      XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "portfolioListId" })?.value, "portfolio-1")
      let contentType = request.value(forHTTPHeaderField: "Content-Type")
      XCTAssertNotNil(contentType)
      XCTAssertTrue(contentType?.starts(with: "multipart/form-data; boundary=") == true)
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
      XCTAssertTrue(bodyString.contains("name=\"provider\""))
      XCTAssertTrue(bodyString.contains("generic"))
      XCTAssertTrue(bodyString.contains("name=\"file\"; filename=\"portfolio-import.csv\""))
      XCTAssertTrue(bodyString.contains("Content-Type: text/csv"))
      XCTAssertTrue(bodyString.contains("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding"))

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
      provider: "generic",
      portfolioListId: "portfolio-1",
      csvData: Data("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testPreviewCsvImport_DecodesEnvelopedResponse() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportPreviewResponse(
      provider: "generic",
      items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: "core holding")],
      errors: []
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv")
      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      let envelope = APIEnvelope(success: true, data: expected, message: nil)
      return (try JSONEncoder().encode(envelope), response)
    }

    let response = try await client.previewCsvImport(
      provider: "generic",
      portfolioListId: nil,
      csvData: Data("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testCommitCsvImport_DecodesEnvelopedResponse() async throws {
    let session = SessionMock()
    let client = BrokerHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = CsvImportCommitResponse(
      provider: "generic",
      inserted: [],
      updated: [],
      errors: [],
      importedLotsCount: 1
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/brokers/import/csv/commit")
      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      let envelope = APIEnvelope(success: true, data: expected, message: nil)
      return (try JSONEncoder().encode(envelope), response)
    }

    let response = try await client.commitCsvImport(
      provider: "generic",
      portfolioListId: nil,
      csvData: Data("symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding".utf8)
    )

    XCTAssertEqual(response, expected)
  }

  func testPreviewCsvImport_WhenUnauthorized_RefreshesAndRetries() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")
    let webAuthenticator = WebAuthenticatorMock()

    let service = BrokerService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session,
      webAuthenticator: webAuthenticator
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

    let response = try await service.previewCsvImport(
      provider: "ibkr",
      portfolioListId: nil,
      csvData: Data("symbol\nAAPL".utf8)
    )
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
    let webAuthenticator = WebAuthenticatorMock()

    let service = BrokerService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session,
      webAuthenticator: webAuthenticator
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
      _ = try await service.commitCsvImport(
        provider: "ibkr",
        portfolioListId: nil,
        csvData: Data("symbol\nAAPL".utf8)
      )
      XCTFail("Expected unauthorized error")
    } catch let error as BrokerHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("retry unauthorized"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 1)
  }

  func testConnectIBKR_StartsBrowserFlowAndLoadsConnection() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    let webAuthenticator = WebAuthenticatorMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    webAuthenticator.result = .success(URL(string: "norviqa://oauth/broker-callback?status=success&broker=ibkr")!)

    let service = BrokerService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session,
      webAuthenticator: webAuthenticator
    )

    var paths: [String] = []
    session.handler = { request in
      let path = request.url?.path ?? ""
      paths.append(path)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )

      switch path {
      case "/v1/brokers/ibkr/connect/start":
        let payload = BrokerConnectStartResponse(
          flowId: UUID().uuidString,
          authorizationURL: "https://api.example.com/v1/auth/brokers/ibkr/callback?flowId=1&state=abc",
          expiresIn: 600
        )
        return (try JSONEncoder().encode(payload), response)
      case "/v1/brokers/ibkr":
        let payload = BrokerConnectionResponse(
          id: UUID().uuidString,
          provider: "ibkr",
          status: "connected"
        )
        return (try JSONEncoder().encode(payload), response)
      default:
        XCTFail("Unexpected path \(path)")
        return (Data(), response)
      }
    }

    let response = try await service.connectIBKR(portfolioListId: "portfolio-1")
    XCTAssertEqual(response.provider, "ibkr")
    XCTAssertEqual(response.status, "connected")
    XCTAssertEqual(paths, ["/v1/brokers/ibkr/connect/start", "/v1/brokers/ibkr"])
  }
}
