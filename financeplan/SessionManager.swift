import Combine
import Foundation

final class SessionManager: ObservableObject {
  static let guestUsername = "Guest"

  @Published var username: String

  init(username: String = SessionManager.guestUsername) {
    self.username = username
  }

  func updateUsername(_ username: String) {
    let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
    self.username = trimmed.isEmpty ? Self.guestUsername : trimmed
  }

  func reset() {
    username = Self.guestUsername
  }
}
