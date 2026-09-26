import XCTest
@testable import financeplan

final class SocialDeepLinkTests: XCTestCase {
  private func parse(_ string: String) -> SocialDeepLink? {
    URL(string: string).flatMap(SocialDeepLink.parse)
  }

  func testParsesUniversalAndCustomSchemeInvites() {
    XCTAssertEqual(parse("https://norviq.org/i/AbC-12_x"), .invite(code: "AbC-12_x"))
    XCTAssertEqual(parse("https://www.norviq.org/i/abcd"), .invite(code: "abcd"))
    XCTAssertEqual(parse("financeplan://invite/abcd1234"), .invite(code: "abcd1234"))
  }

  func testIgnoresLinksThatAreNotInvites() {
    XCTAssertNil(parse("https://norviq.org/p/some-portfolio"))
    XCTAssertNil(parse("https://norviq.org/i/"))
    XCTAssertNil(parse("https://evil.example/i/abcd"))
    XCTAssertNil(parse("http://norviq.org/i/abcd"))
    XCTAssertNil(parse("financeplan://assistant/conversations/abcd"))
    XCTAssertNil(parse("norviqa://oauth/callback"))
  }

  func testRejectsCodesThatCouldEscapeThePath() {
    XCTAssertNil(SocialDeepLink.normalizedCode("abc"))
    XCTAssertNil(SocialDeepLink.normalizedCode("abcd/../x"))
    XCTAssertNil(SocialDeepLink.normalizedCode("abcd?x=1"))
    XCTAssertNil(SocialDeepLink.normalizedCode("ábcd"))
    XCTAssertNil(SocialDeepLink.normalizedCode(String(repeating: "a", count: 65)))
    XCTAssertEqual(SocialDeepLink.normalizedCode("  abcd  "), "abcd")
  }

  func testInviteURLRoundTrips() throws {
    let url = try XCTUnwrap(SocialDeepLink.inviteURL(code: "abcd1234"))
    XCTAssertEqual(SocialDeepLink.parse(url), .invite(code: "abcd1234"))
  }

  func testFriendPushesParseToSocialKinds() {
    let request = PushNotificationPayloadParser.parse(userInfo: ["type": "friend_request"])
    XCTAssertEqual(request?.kind, .friendRequest)
    let accepted = PushNotificationPayloadParser.parse(userInfo: ["data": ["type": "friend_accepted"]])
    XCTAssertEqual(accepted?.kind, .friendAccepted)
  }
}
