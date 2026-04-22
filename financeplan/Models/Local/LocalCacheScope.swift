import Foundation
import SwiftData

enum LocalCacheScope {
  static var currentOwnerUserId: String {
    UserDefaults.standard.string(forKey: "current_user_id")?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  static func isOwnedByCurrentUser(_ ownerUserId: String?, currentUserId: String = currentOwnerUserId) -> Bool {
    guard !currentUserId.isEmpty else { return false }
    return ownerUserId == currentUserId
  }
}
