import Foundation

enum AuthValidation {
  enum PasswordStrength: Equatable {
    case weak
    case medium
    case strong
  }

  static func isValidEmail(_ value: String) -> Bool {
    let emailRegex = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
    return value.range(of: emailRegex, options: .regularExpression) != nil
  }

  static func isValidUsername(_ value: String) -> Bool {
    let usernameRegex = #"^[a-zA-Z0-9_]{4,30}$"#
    return value.range(of: usernameRegex, options: .regularExpression) != nil
  }

  static func isValidPassword(_ value: String) -> Bool {
    value.count >= 8
  }

  static func isStrongPassword(_ value: String) -> Bool {
    passwordRuleScore(value) == 5
  }

  static func passwordRuleScore(_ value: String) -> Int {
    let uppercase = CharacterSet.uppercaseLetters
    let lowercase = CharacterSet.lowercaseLetters
    let digits = CharacterSet.decimalDigits
    let symbols = CharacterSet.punctuationCharacters.union(.symbols)

    var score = 0
    if value.count >= 8 { score += 1 }
    if value.unicodeScalars.contains(where: { uppercase.contains($0) }) { score += 1 }
    if value.unicodeScalars.contains(where: { lowercase.contains($0) }) { score += 1 }
    if value.unicodeScalars.contains(where: { digits.contains($0) }) { score += 1 }
    if value.unicodeScalars.contains(where: { symbols.contains($0) }) { score += 1 }
    return score
  }

  static func passwordStrength(_ value: String) -> PasswordStrength {
    let score = passwordRuleScore(value)
    if score >= 5 { return .strong }
    if score >= 3 { return .medium }
    return .weak
  }
}
