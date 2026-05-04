import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PushNotificationsHTTPClientTests: XCTestCase {
  private final class SessionMock: PushNotificationsURLSessionProtocol, @unchecked Sendable, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  func testRegisterDevice_UsesExpectedPathMethodHeadersAndBody() async throws {
    let session = SessionMock()
    let client = PushNotificationsHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    let expected = PushDeviceRegistrationResponse(
      id: "device-1",
      deviceToken: "abc123",
      platform: .ios,
      apnsEnvironment: .development,
      authorizationStatus: .authorized,
      isActive: true,
      lastSeenAt: "2026-04-10T10:30:00Z"
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.url?.path, "/v1/notifications/apns/device")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder.stockPlanShared.decode(PushDeviceRegistrationRequest.self, from: body)
      XCTAssertEqual(decoded.deviceToken, "abc123")
      XCTAssertEqual(decoded.platform, .ios)
      XCTAssertEqual(decoded.apnsEnvironment, .development)
      XCTAssertEqual(decoded.authorizationStatus, .authorized)

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder.stockPlanShared.encode(expected), response)
    }

    let response = try await client.registerDevice(
      PushDeviceRegistrationRequest(
        deviceToken: "abc123",
        platform: .ios,
        apnsEnvironment: .development,
        authorizationStatus: .authorized
      )
    )

    XCTAssertEqual(response, expected)
  }

  func testDeactivateDevice_UsesExpectedPathMethodAndBody() async throws {
    let session = SessionMock()
    let client = PushNotificationsHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/notifications/apns/device/deactivate")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder.stockPlanShared.decode(PushDeviceDeactivateRequest.self, from: body)
      XCTAssertEqual(decoded.deviceToken, "abc123")

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (Data(), response)
    }

    try await client.deactivateDevice(PushDeviceDeactivateRequest(deviceToken: "abc123"))
  }
}
