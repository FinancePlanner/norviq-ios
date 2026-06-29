import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AccountLinkingHTTPClientTests: XCTestCase {
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  func testListLinkedAccounts_UsesBearerTokenAndDecodesResponse() async throws {
    let session = SessionMock()
    let client = AccountLinkingHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let expected = OAuthLinkedAccountsResponse(accounts: [
      OAuthLinkedAccount(provider: .apple, connected: false),
      OAuthLinkedAccount(provider: .google, connected: true, email: "user@example.com", emailVerified: true),
      OAuthLinkedAccount(provider: .x, connected: false)
    ])

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v1/auth/oauth/identities")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder.stockPlanShared.encode(expected), response)
    }

    let response = try await client.listLinkedAccounts()
    XCTAssertEqual(response, expected)
  }

  func testLinkStartAndExchange_UseAuthenticatedLinkEndpoints() async throws {
    let session = SessionMock()
    let client = AccountLinkingHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let flowId = UUID()
    var paths: [String] = []

    session.handler = { request in
      paths.append(request.url?.path ?? "")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      if request.url?.path == "/v1/auth/oauth/google/link/start" {
        XCTAssertEqual(request.httpMethod, "POST")
        return (
          try JSONEncoder.stockPlanShared.encode(
            OAuthStartResponse(flowId: flowId, authorizationURL: "https://oauth.example.test", expiresIn: 600)
          ),
          response
        )
      }
      XCTAssertEqual(request.url?.path, "/v1/auth/oauth/google/link/exchange")
      XCTAssertEqual(request.httpMethod, "POST")
      return (
        try JSONEncoder.stockPlanShared.encode(
          OAuthLinkResponse(provider: .google, connected: true, email: "user@example.com", message: "Connected.")
        ),
        response
      )
    }

    let start = try await client.linkStart(provider: .google, redirectURI: "norviqa://oauth/callback")
    let result = try await client.linkExchange(
      provider: .google,
      request: OAuthExchangeRequest(
        flowId: start.flowId,
        code: "code-123",
        state: "state-123",
        redirectURI: "norviqa://oauth/callback"
      )
    )

    XCTAssertEqual(paths, ["/v1/auth/oauth/google/link/start", "/v1/auth/oauth/google/link/exchange"])
    XCTAssertEqual(result.provider, .google)
    XCTAssertTrue(result.connected)
  }
}
