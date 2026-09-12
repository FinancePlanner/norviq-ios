import XCTest
@testable import financeplan

@MainActor
final class AppLanguageTests: XCTestCase {
  override func tearDown() {
    super.tearDown()
    UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
  }

  func testFromRawValueDefaultsToEnglish() async {
    await Task.yield()
    XCTAssertEqual(AppLanguage.from("unsupported"), .english)
  }

  func testLocaleIdentifiers() async {
    await Task.yield()
    XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
    XCTAssertEqual(AppLanguage.portuguesePortugal.localeIdentifier, "pt-PT")
  }

  func testDisplayNames() async {
    await Task.yield()
    XCTAssertEqual(AppLanguage.english.displayName, "English")
    XCTAssertEqual(AppLanguage.portuguesePortugal.displayName, "Português")
  }

  func testLocalizedStringUsesSelectedLanguage() async {
    await Task.yield()
    XCTAssertEqual(AppLanguage.english.localized(english: "Home", portuguese: "Início"), "Home")
    XCTAssertEqual(AppLanguage.portuguesePortugal.localized(english: "Home", portuguese: "Início"), "Início")
  }

  func testApplyEnglishStoresBundleLanguagePreference() async {
    await Task.yield()
    AppLanguage.apply(.english)

    XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "en")
    XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["en"])
  }

  /// Async with no suspension point: this test mutates UserDefaults.standard and
  /// aborts if an `await` is introduced, but a synchronous test in a @MainActor
  /// class aborts the whole process. The test-target .swiftformat keeps `async`
  /// from being stripped for want of an `await`.
  func testApplyStoredLanguageDefaultsFreshInstallToEnglish() async {
    UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")

    AppLanguage.applyStoredLanguage()

    XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "en")
    XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["en"])
  }

  func testApplyPortugueseStoresBundleLanguagePreference() async {
    await Task.yield()
    AppLanguage.apply(.portuguesePortugal)

    XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "pt-PT")
    XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["pt-PT", "pt"])
  }
}
