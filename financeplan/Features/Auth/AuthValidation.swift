import Foundation

enum AuthValidation {
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
}
