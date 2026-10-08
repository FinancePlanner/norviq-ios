import XCTest
@testable import financeplan

final class InviteChannelsTests: XCTestCase {
  private let invite = URL(string: "https://norviq.org/i/Ab3_x-9Kq0")!

  func testMessageEndsWithTheInviteLink() {
    let text = InviteMessage.text(for: invite)
    XCTAssertTrue(text.hasPrefix("Let's track our goals together on Norviq"))
    XCTAssertTrue(text.hasSuffix(invite.absoluteString))
  }

  func testMessengerAppURLCarriesTheEncodedLink() throws {
    let url = try XCTUnwrap(MessengerShare.appURL(for: invite))
    XCTAssertEqual(url.scheme, "fb-messenger")
    XCTAssertEqual(url.host, "share")
    XCTAssertFalse(url.absoluteString.contains("https://norviq.org"), "link must be percent-encoded")
    XCTAssertEqual(link(in: url, named: "link"), invite.absoluteString)
  }

  func testWebFallbackIsTheFacebookSharerWithTheEncodedLink() throws {
    let url = try XCTUnwrap(MessengerShare.webFallbackURL(for: invite))
    XCTAssertEqual(url.host, "www.facebook.com")
    XCTAssertEqual(url.path, "/sharer/sharer.php")
    XCTAssertFalse(url.absoluteString.contains("https://norviq.org"), "link must be percent-encoded")
    XCTAssertEqual(link(in: url, named: "u"), invite.absoluteString)
  }

  private func link(in url: URL, named name: String) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first { $0.name == name }?
      .value
  }
}
