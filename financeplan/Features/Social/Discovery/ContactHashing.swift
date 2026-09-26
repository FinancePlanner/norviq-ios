import CryptoKit
import Foundation

/// Contact hashing, version 1, byte-for-byte what the server computes for its
/// users: `hex(HMAC-SHA256(key: pepper, message: lowercase(trim(email))))`.
/// Raw addresses never leave the phone. Accounts have no phone numbers, so
/// only emails are matched.
nonisolated enum ContactHashing {
  static let version = 1

  static func normalizedEmail(_ raw: String) -> String? {
    let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard email.contains("@"), email.count >= 3 else { return nil }
    return email
  }

  static func hash(email: String, pepper: String) -> String? {
    guard let normalized = normalizedEmail(email) else { return nil }
    let code = HMAC<SHA256>.authenticationCode(
      for: Data(normalized.utf8),
      using: SymmetricKey(data: Data(pepper.utf8))
    )
    return code.map { String(format: "%02x", $0) }.joined()
  }

  /// Unique hashes for a set of addresses, in batches the server accepts.
  static func batches(emails: [String], pepper: String, batchSize: Int = 1_000) -> [[ContactHashItem]] {
    let hashes = Set(emails.compactMap { hash(email: $0, pepper: pepper) }).sorted()
    return stride(from: 0, to: hashes.count, by: batchSize).map { start in
      hashes[start..<min(start + batchSize, hashes.count)].map { ContactHashItem(hash: $0, kind: .email) }
    }
  }
}
