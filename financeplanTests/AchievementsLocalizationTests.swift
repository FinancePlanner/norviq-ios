import Foundation
import XCTest

/// Every string the achievements screens add has a European Portuguese
/// translation in the catalog.
final class AchievementsLocalizationTests: XCTestCase {
  static let keys = [
    "Achievements", "Showcase", "Unlocked %lld of %lld", "%lld hidden achievements left to find",
    "Long-press an achievement to pin it to your profile.", "Pinned", "Unpin from profile", "Pin to profile",
    "%@ earned", "%@ not yet earned", "Gold", "Silver", "Bronze", "You can pin up to 3 achievements.",
    "Couldn't update your showcase. Try again.", "%lld achievements unlocked", "Achievement unlocked", "+%lld XP",
    "View all achievements", "No achievements yet", "When friends unlock achievements, they show up here.",
    "unlocked", "That achievement is no longer available.", "Couldn't send your congrats. Try again.",
    "Congratulated", "Congratulate", "%lld cheers", "Nothing to show here yet.", "%@ doesn't share achievements.",
    "Feed", "All achievements", "Show achievements to friends"
  ]

  func testEveryAchievementsStringHasPortuguese() throws {
    let catalogURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("financeplan/Localizable.xcstrings")
    let catalog = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
    )
    let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
    for key in Self.keys {
      let entry = strings[key] as? [String: Any]
      let localizations = entry?["localizations"] as? [String: Any]
      let portuguese = (localizations?["pt-PT"] as? [String: Any])?["stringUnit"] as? [String: Any]
      XCTAssertEqual(portuguese?["state"] as? String, "translated", "missing pt-PT for \(key)")
      XCTAssertFalse((portuguese?["value"] as? String ?? "").isEmpty, "empty pt-PT for \(key)")
    }
  }
}
