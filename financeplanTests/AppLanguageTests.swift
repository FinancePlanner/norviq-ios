import XCTest

@testable import financeplan

final class AppLanguageTests: XCTestCase {
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
}
