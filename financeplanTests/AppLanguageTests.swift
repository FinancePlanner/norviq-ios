import XCTest

@testable import financeplan

@MainActor
final class AppLanguageTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    func testFromRawValueDefaultsToEnglish() {
        XCTAssertEqual(AppLanguage.from("unsupported"), .english)
    }

    func testLocaleIdentifiers() {
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.portuguesePortugal.localeIdentifier, "pt-PT")
    }

    func testDisplayNames() {
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.portuguesePortugal.displayName, "Português")
    }

    func testApplyEnglishStoresBundleLanguagePreference() {
        AppLanguage.apply(.english)

        XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "en")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["en"])
    }

    func testApplyPortugueseStoresBundleLanguagePreference() {
        AppLanguage.apply(.portuguesePortugal)

        XCTAssertEqual(UserDefaults.standard.string(forKey: AppLanguage.storageKey), "pt-PT")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["pt-PT", "pt"])
    }
}
