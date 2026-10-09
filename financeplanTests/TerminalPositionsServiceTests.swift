import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class TerminalPositionsServiceTests: XCTestCase {
  private final class AuthMock: AuthSessionManaging, @unchecked Sendable {
    var validToken: String? = "old"
    var refreshedToken: String? = "new"
    private(set) var refreshCalls = 0
    private(set) var invalidateCalls = 0

    func restoreSessionIfNeeded() async -> Bool {
      true
    }

    func validAccessToken() async throws -> String? {
      validToken
    }

    func refreshAccessToken() async throws -> String? {
      refreshCalls += 1
      return refreshedToken
    }

    func logout() async {}
    func invalidateSession() async {
      invalidateCalls += 1
    }
  }

  private func makeService(_ session: TerminalSessionMock, auth: AuthMock) -> TerminalPositionsService {
    TerminalPositionsService(environmentManager: AppEnvironmentManager(), authSessionManager: auth, session: session)
  }

  func testRefreshesTheTokenOnceAfterA401() async throws {
    let session = TerminalSessionMock()
    session.handler = { request in
      if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
        return terminalHTTPResponse(request, status: 401, json: #"{"error":true,"reason":"expired"}"#)
      }
      return terminalHTTPResponse(request, status: 200, json: #"{"currency":"USD","positions":[]}"#)
    }
    let auth = AuthMock()

    let list = try await makeService(session, auth: auth).list(ticker: nil)

    XCTAssertEqual(list.positions, [])
    XCTAssertEqual(auth.refreshCalls, 1)
    XCTAssertEqual(auth.invalidateCalls, 0)
  }

  func testInvalidatesTheSessionWhenTheRefreshedTokenIsAlsoRejected() async {
    let session = TerminalSessionMock()
    session.handler = { request in
      terminalHTTPResponse(request, status: 401, json: #"{"error":true,"reason":"expired"}"#)
    }
    let auth = AuthMock()

    do {
      _ = try await makeService(session, auth: auth).summary()
      XCTFail("Expected unauthorized")
    } catch {
      XCTAssertTrue((error as? TerminalPositionsHTTPClient.Error)?.isUnauthorized ?? false)
    }
    XCTAssertEqual(auth.refreshCalls, 1)
    XCTAssertEqual(auth.invalidateCalls, 1)
  }

  func testNoTokenFailsWithoutARequest() async {
    let session = TerminalSessionMock()
    session.handler = { request in terminalHTTPResponse(request, status: 200) }
    let auth = AuthMock()
    auth.validToken = nil

    do {
      _ = try await makeService(session, auth: auth).autobuys()
      XCTFail("Expected notAuthenticated")
    } catch {
      XCTAssertTrue(session.requests.isEmpty)
    }
  }
}
