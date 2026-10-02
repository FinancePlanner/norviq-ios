import XCTest
@testable import financeplan

final class ContactHashingTests: XCTestCase {
  /// Same vector as the backend's SocialContactHashTests: if either side
  /// changes normalization or encoding, contacts silently stop matching.
  func testMatchesTheServerVector() {
    XCTAssertEqual(
      ContactHashing.hash(email: "  Ana@Example.com ", pepper: "test-pepper"),
      "daee873047f0f98be24af583ad20cf23023f1772bfa853aed2bb53967227737f"
    )
  }

  func testRejectsValuesThatAreNotEmails() {
    XCTAssertNil(ContactHashing.hash(email: "not-an-email", pepper: "p"))
    XCTAssertNil(ContactHashing.hash(email: "   ", pepper: "p"))
  }

  func testBatchesDeduplicateAndSplit() {
    let emails = (0..<2_500).map { "person\($0)@example.com" } + ["PERSON0@example.com"]
    let batches = ContactHashing.batches(emails: emails, pepper: "p")
    XCTAssertEqual(batches.map(\.count), [1_000, 1_000, 500])
    XCTAssertEqual(Set(batches.flatMap { $0 }.map(\.hash)).count, 2_500)
    XCTAssertTrue(batches.allSatisfy { $0.allSatisfy { $0.kind == .email && $0.hash.count == 64 } })
  }

  func testConfigDecodesWithoutDiscoveryFields() throws {
    let json = Data(#"{"enabled":true,"contactsDiscovery":false,"xImport":false,"leaderboards":false,"messaging":false}"#.utf8)
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertNil(config.contactPepper)
    XCTAssertTrue(config.enabled)
    XCTAssertFalse(config.facebookImport)
  }
}
