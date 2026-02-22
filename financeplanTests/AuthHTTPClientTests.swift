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

  func testForgotPassword_WhenServerReturnsNonJSONError_ThrowsStatusError() async throws {
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
      XCTFail("Expected invalid status error")
    } catch let error as AuthHTTPClient.Error {
      XCTAssertEqual(error, .invalidStatus(500))
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
}
