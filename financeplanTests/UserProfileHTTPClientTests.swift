import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class UserProfileHTTPClientTests: XCTestCase {
  private final class SessionMock: UserProfileURLSessionProtocol {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  func testFetchProfile_SendsAuthHeaderAndDecodesResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let expectedProfile = StockPlanShared.UserProfile(
      id: "user-123",
      email: "user@example.com",
      bio: "Hello",
      avatarURL: URL(string: "https://cdn.example.com/avatar.png"),
      bannerAvatarURL: URL(string: "https://cdn.example.com/banner.png"),
      username: "user123",
      firstName: "Jane",
      lastName: "Doe"
    )
    let expectedResponse = GetUserProfileResponse(userProfile: expectedProfile)

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertNil(request.httpBody)

      let data = try JSONEncoder().encode(expectedResponse)
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = UserProfileHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let response = try await client.fetchProfile(GetUserProfileRequest(id: "user-123"))

    XCTAssertEqual(response, expectedResponse)
  }

  func testUpdateProfile_EncodesSharedRequestAndDecodesEnvelope() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let profile = StockPlanShared.UserProfile(
      id: "user-123",
      email: "user@example.com",
      bio: "Updated bio",
      avatarURL: nil,
      bannerAvatarURL: nil,
      username: "updated_user",
      firstName: "Jane",
      lastName: "Doe"
    )
    let requestDTO = UpdateUserProfileRequest(userProfile: profile)
    let expectedResponse = UpdateUserProfileResponse(userProfile: profile)

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder().decode(UpdateUserProfileRequest.self, from: body)
      XCTAssertEqual(decoded, requestDTO)

      let data = try JSONEncoder().encode(
        APIEnvelope(success: true, data: expectedResponse, message: nil)
      )
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = UserProfileHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let response = try await client.updateProfile(requestDTO)

    XCTAssertEqual(response, expectedResponse)
  }

  func testDeleteProfile_WhenServerReturnsAPIError_ThrowsAPIError() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")

      let data = #"{"error":"Profile not found"}"#.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let client = UserProfileHTTPClient(baseURL: baseURL, session: session)

    do {
      _ = try await client.deleteProfile(DeleteUserProfileRequest(id: "missing-user"))
      XCTFail("Expected API error")
    } catch let error as UserProfileHTTPClient.Error {
      XCTAssertEqual(error, .api("Profile not found"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
