import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AuthHTTPClientTests: XCTestCase {
  private final class SessionMock: AuthURLSessionProtocol {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  func testLogin_SendsCorrectRequestAndDecodesResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let expected = AuthResponse(
      token: "token-123",
      userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      expiresIn: 3600,
      refreshToken: "refresh-123",
      refreshExpiresIn: 86_400,
      username: "valid_user",
      email: "user@example.com",
      firstName: "Jane",
      lastName: "Doe",
      dateOfBirth: Date(timeIntervalSince1970: 946684800)
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/login")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder().decode(AuthLoginRequest.self, from: body)
      XCTAssertEqual(decoded.email, "user@example.com")
      XCTAssertEqual(decoded.password, "Password123")

      let data = try JSONEncoder().encode(expected)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)
    let response = try await client.login(
      AuthLoginRequest(email: "user@example.com", password: "Password123")
    )

    XCTAssertEqual(response, expected)
  }

  func testRegister_WhenServerReturnsAPIError_ThrowsAPIError() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/register")

      let data = #"{"error":"Email already in use"}"#.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 409, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)

    do {
      _ = try await client.register(
        AuthRegisterRequest(
          username: "dupe_user",
          password: "Password123",
          email: "dupe@example.com",
          firstName: "Dupe",
          lastName: "User",
          dateOfBirth: Date(timeIntervalSince1970: 946684800)
        )
      )
      XCTFail("Expected API error")
    } catch let error as AuthHTTPClient.Error {
      XCTAssertEqual(error, .api("Email already in use"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRegister_WhenServerReturnsReasonField_ThrowsAPIErrorReason() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/register")

      let data = #"{"error":true,"reason":"Username already registered"}"#.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 409, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)

    do {
      try await client.register(
        AuthRegisterRequest(
          username: "dupe_user",
          password: "Password123",
          email: "dupe@example.com",
          firstName: "Dupe",
          lastName: "User",
          dateOfBirth: Date(timeIntervalSince1970: 946684800)
        )
      )
      XCTFail("Expected API error")
    } catch let error as AuthHTTPClient.Error {
      XCTAssertEqual(error, .api("Username already registered"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRegister_WhenServerReturnsSuccessWithoutAuthPayload_DoesNotThrow() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/register")
      let data = #"{"ok":true}"#.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 201, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)

    try await client.register(
      AuthRegisterRequest(
        username: "new_user",
        password: "Password123",
        email: "new@example.com",
        firstName: "New",
        lastName: "User",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )
  }

  func testForgotPassword_WhenServerReturnsNonJSONError_ThrowsAPIErrorWithRawMessage() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/forgot-password")
      let data = Data("Internal Error".utf8)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)

    do {
      _ = try await client.forgotPassword(AuthForgotPasswordRequest(email: "user@example.com"))
      XCTFail("Expected API error")
    } catch let error as AuthHTTPClient.Error {
      XCTAssertEqual(error, .api("Internal Error"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testForgotPassword_DecodesResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      let expected = AuthForgotPasswordResponse(
        message: "If the account exists, a reset code has been sent.",
        resetCode: nil
      )
      let data = try JSONEncoder().encode(expected)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)
    let response = try await client.forgotPassword(AuthForgotPasswordRequest(email: "user@example.com"))

    XCTAssertEqual(response.message, "If the account exists, a reset code has been sent.")
    XCTAssertNil(response.resetCode)
  }

  func testRefresh_SendsCorrectRequestAndDecodesResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let expected = AuthResponse(
      token: "new-token-123",
      userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      expiresIn: 3600,
      refreshToken: "new-refresh-123",
      refreshExpiresIn: 86_400,
      username: "valid_user",
      email: "user@example.com",
      firstName: "Jane",
      lastName: "Doe",
      dateOfBirth: Date(timeIntervalSince1970: 946684800)
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/auth/refresh")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder().decode(AuthRefreshRequest.self, from: body)
      XCTAssertEqual(decoded.refreshToken, "refresh-123")

      let data = try JSONEncoder().encode(expected)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)
    let response = try await client.refresh(AuthRefreshRequest(refreshToken: "refresh-123"))

    XCTAssertEqual(response, expected)
  }

  func testLogin_DecodesSnakeCaseDBStyleDateResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let expected = AuthResponse(
      token: "token-123",
      userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      expiresIn: 3600,
      refreshToken: "refresh-123",
      refreshExpiresIn: 86_400,
      username: "valid_user",
      email: "user@example.com",
      firstName: "Jane",
      lastName: "Doe",
      dateOfBirth: Date(timeIntervalSince1970: 1_136_073_600)
    )

    session.handler = { request in
      let payload = """
      {
        "token": "token-123",
        "user_id": "11111111-1111-1111-1111-111111111111",
        "expires_in": 3600,
        "refresh_token": "refresh-123",
        "refresh_expires_in": 86400,
        "username": "valid_user",
        "email": "user@example.com",
        "first_name": "Jane",
        "last_name": "Doe",
        "date_of_birth": "2006-01-01 00:00:00 +0000"
      }
      """.data(using: .utf8) ?? Data()

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (payload, response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)
    let response = try await client.login(
      AuthLoginRequest(email: "user@example.com", password: "Password123")
    )

    XCTAssertEqual(response, expected)
  }

  func testLogout_WhenV2Returns404_FallsBackToAuthLogout() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    var requestedURLs: [String] = []

    session.handler = { request in
      let url = try XCTUnwrap(request.url).absoluteString
      requestedURLs.append(url)

      if url == "https://api.example.com/v2/logout" {
        let response = try XCTUnwrap(
          HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)
        )
        return (Data(), response)
      }

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (Data(), response)
    }

    let client = AuthHTTPClient(baseURL: baseURL, session: session)
    try await client.logout(AuthRefreshRequest(refreshToken: "refresh-123"))

    XCTAssertEqual(
      requestedURLs,
      [
        "https://api.example.com/v2/logout",
        "https://api.example.com/auth/logout",
      ]
    )
  }
}
