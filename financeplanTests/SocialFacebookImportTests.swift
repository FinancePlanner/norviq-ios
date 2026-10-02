import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class SocialFacebookImportTests: XCTestCase {
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private func makeClient(_ session: SessionMock) -> SocialHTTPClient {
    SocialHTTPClient(baseURL: URL(string: "https://api.example.com")!, session: session, authTokenProvider: { "token-123" })
  }

  private func respond(_ request: URLRequest, status: Int, body: String) throws -> (Data, URLResponse) {
    let response = try XCTUnwrap(
      HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)
    )
    return (Data(body.utf8), response)
  }

  // MARK: - Decoding

  func testConfigWithoutFacebookImportReadsAsOff() throws {
    let json = Data(#"{"enabled":true,"contactsDiscovery":true,"xImport":true,"leaderboards":false,"messaging":false}"#.utf8)
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertFalse(config.facebookImport)
    XCTAssertTrue(config.xImport)
  }

  func testConfigDecodesFacebookImport() throws {
    let json = Data(
      #"{"enabled":true,"contactsDiscovery":false,"xImport":false,"facebookImport":true,"leaderboards":false,"messaging":false,"contactHashVersion":1,"contactPepper":"p"}"#.utf8
    )
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertTrue(config.facebookImport)
    XCTAssertEqual(config.contactHashVersion, 1)
    XCTAssertEqual(config.contactPepper, "p")
  }

  func testPrivacyWithoutFacebookSwitchReadsAsDiscoverable() throws {
    let json = Data(
      #"{"searchVisibility":"friends_of_friends","discoverableByContacts":false,"discoverableByX":false,"showReturnPercent":false,"showStreaks":true,"showXP":true,"leaderboardOptIn":true}"#.utf8
    )
    let settings = try JSONDecoder().decode(SocialPrivacySettings.self, from: json)
    XCTAssertTrue(settings.discoverableByFacebook)
    XCTAssertFalse(settings.discoverableByX)
    XCTAssertEqual(settings.searchVisibility, .friendsOfFriends)
  }

  func testPrivacyRoundTripsFacebookSwitch() throws {
    var settings = SocialPrivacySettings.default
    settings.discoverableByFacebook = false
    let data = try JSONEncoder().encode(settings)
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["discoverableByFacebook"] as? Bool, false)
    XCTAssertEqual(try JSONDecoder().decode(SocialPrivacySettings.self, from: data), settings)
  }

  // MARK: - Endpoints (HTTP methods are checked on the wire in the client tests)

  func testLimitedImportEndpointCarriesTokenAndNonce() throws {
    let endpoint = FacebookLimitedImportEndpoint(payload: FacebookLimitedLoginRequest(idToken: "jwt", nonce: "n-1"))
    XCTAssertEqual(endpoint.path, "/v1/social/discovery/facebook/limited")
    let parameters = try endpoint.asParameters()
    XCTAssertEqual(parameters["idToken"] as? String, "jwt")
    XCTAssertEqual(parameters["nonce"] as? String, "n-1")
    XCTAssertEqual(parameters.count, 2)
  }

  func testDisconnectEndpointPath() throws {
    let endpoint = DisconnectFacebookEndpoint()
    XCTAssertEqual(endpoint.path, "/v1/social/discovery/facebook")
    XCTAssertTrue(try endpoint.asParameters().isEmpty)
  }

  // MARK: - Client

  func testImportSendsBodyAndDecodesMatches() async throws {
    let session = SessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/social/discovery/facebook/limited")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let body = try XCTUnwrap(request.httpBody)
      let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: String])
      XCTAssertEqual(object, ["idToken": "jwt", "nonce": "n-1"])
      return try self.respond(
        request,
        status: 200,
        body: #"{"matches":[{"user":{"id":"ana","username":"ana","displayName":"Ana","friendshipStatus":"none"}}],"friendsGranted":3}"#
      )
    }

    let response = try await makeClient(session).importFacebookFriends(FacebookLimitedLoginRequest(idToken: "jwt", nonce: "n-1"))
    XCTAssertEqual(response.matches.map(\.id), ["ana"])
    XCTAssertEqual(response.friendsGranted, 3)
  }

  func testDisconnectAcceptsNoContent() async throws {
    let session = SessionMock()
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.url?.path, "/v1/social/discovery/facebook")
      return try self.respond(request, status: 204, body: "")
    }
    try await makeClient(session).disconnectFacebook()
  }

  func testConflictShowsTheServerReason() async throws {
    let session = SessionMock()
    session.handler = { request in
      try self.respond(request, status: 409, body: #"{"error":true,"reason":"Already linked elsewhere."}"#)
    }
    do {
      _ = try await makeClient(session).importFacebookFriends(FacebookLimitedLoginRequest(idToken: "jwt", nonce: "n"))
      XCTFail("Expected a conflict")
    } catch {
      XCTAssertEqual(FacebookImportView.message(for: error), "Already linked elsewhere.")
    }
  }

  func testConflictWithoutReasonFallsBackToExplanation() {
    XCTAssertEqual(
      FacebookImportView.message(for: SocialHTTPClient.Error.invalidStatus(409)),
      "This Facebook account is already connected to another Norviq account."
    )
  }

  // MARK: - SDK seam

  func testFacebookIsUnavailableWithoutAnAppID() {
    // The test host is built with FACEBOOK_APP_ID empty.
    XCTAssertFalse(FacebookConnect.isAvailable)
    XCTAssertFalse(FacebookConnect.handle(URL(string: "fb://authorize")!))
  }
}
