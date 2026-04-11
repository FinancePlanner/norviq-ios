import XCTest
@testable import financeplan

@MainActor
final class AuthValidationTests: XCTestCase {
  func testIsValidEmail_WithValidEmail_ReturnsTrue() {
    XCTAssertTrue(AuthValidation.isValidEmail("user@example.com"))
  }

  func testIsValidEmail_WithInvalidEmail_ReturnsFalse() {
    XCTAssertFalse(AuthValidation.isValidEmail("invalid-email"))
    XCTAssertFalse(AuthValidation.isValidEmail("user@"))
    XCTAssertFalse(AuthValidation.isValidEmail("@example.com"))
  }

  func testIsValidUsername_WithAllowedCharacters_ReturnsTrue() {
    XCTAssertTrue(AuthValidation.isValidUsername("john_doe_123"))
  }

  func testIsValidUsername_WithDisallowedCharactersOrLength_ReturnsFalse() {
    XCTAssertFalse(AuthValidation.isValidUsername("ab"))
    XCTAssertFalse(AuthValidation.isValidUsername("john.doe"))
    XCTAssertFalse(AuthValidation.isValidUsername("john-doe"))
  }

  func testIsValidPassword_WithMinimumLength_ReturnsTrue() {
    XCTAssertTrue(AuthValidation.isValidPassword("Password123"))
  }

  func testIsValidPassword_WithShortLength_ReturnsFalse() {
    XCTAssertFalse(AuthValidation.isValidPassword("short"))
  }

  func testIsStrongPassword_WithAllRequirements_ReturnsTrue() {
    XCTAssertTrue(AuthValidation.isStrongPassword("Password123!"))
  }

  func testIsStrongPassword_WithoutSymbol_ReturnsFalse() {
    XCTAssertFalse(AuthValidation.isStrongPassword("Password123"))
  }

  func testPasswordStrength_ReturnsWeakMediumAndStrong() {
    XCTAssertEqual(AuthValidation.passwordStrength("abc"), .weak)
    XCTAssertEqual(AuthValidation.passwordStrength("Password123"), .medium)
    XCTAssertEqual(AuthValidation.passwordStrength("Password123!"), .strong)
  }
}
