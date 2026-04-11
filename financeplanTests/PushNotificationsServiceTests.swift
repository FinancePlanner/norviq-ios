import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PushNotificationsServiceTests: XCTestCase {
  private final class SessionMock: PushNotificationsURLSessionProtocol {
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

    func logout() async {}

    func invalidateSession() async {
      invalidateSessionCalls += 1
    }
  }

  private enum MockError: Error {
    case notConfigured
  }

  func testRegisterDevice_WhenUnauthorized_RefreshesAndRetries() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")

    let service = PushNotificationsService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session
    )

    var requestCount = 0
    session.handler = { request in
      requestCount += 1
      let responseURL = try XCTUnwrap(request.url)

      if requestCount == 1 {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
        let response = try XCTUnwrap(
          HTTPURLResponse(url: responseURL, statusCode: 401, httpVersion: nil, headerFields: nil)
        )
        return (#"{"error":"expired"}"#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
      let payload = PushDeviceRegistrationResponse(
        id: "device-1",
        deviceToken: "abc123",
        platform: .ios,
        apnsEnvironment: .development,
        authorizationStatus: .authorized,
        isActive: true,
        lastSeenAt: "2026-04-10T10:30:00Z"
      )
      let response = try XCTUnwrap(
        HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder.stockPlanShared.encode(payload), response)
    }

    let response = try await service.registerDevice(
      deviceToken: "abc123",
      apnsEnvironment: .development,
      authorizationStatus: .authorized
    )

    XCTAssertEqual(response.deviceToken, "abc123")
    XCTAssertEqual(requestCount, 2)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 0)
  }

  func testDeactivateDevice_WhenRetryUnauthorized_InvalidatesSession() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")

    let service = PushNotificationsService(
      environmentManager: AppEnvironmentManager(),
      authSessionManager: authSessionManager,
      session: session
    )

    session.handler = { request in
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)
      )
      if request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token" {
        return (#"{"error":"retry unauthorized"}"#.data(using: .utf8) ?? Data(), response)
      }
      return (#"{"error":"expired"}"#.data(using: .utf8) ?? Data(), response)
    }

    do {
      try await service.deactivateDevice(deviceToken: "abc123")
      XCTFail("Expected unauthorized error")
    } catch let error as PushNotificationsHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("retry unauthorized"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 1)
  }
}
