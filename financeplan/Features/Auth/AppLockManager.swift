import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum AppDeviceAuthenticationResult: Equatable {
  case authenticated
  case failed
  case unavailable
}

enum AppLockEnforcementResult: Equatable {
  case notRequired
  case unlocked
  case locked
  case requiresReauthentication
}

@MainActor
protocol AppLockManaging: AnyObject {
  var isLocked: Bool { get }
  func appDidEnterBackground()
  func enforceIfNeeded(isAuthenticated: Bool, isEnabled: Bool) async -> AppLockEnforcementResult
  func authenticateDevice(localizedReason: String) async -> AppDeviceAuthenticationResult
  func unlock() async -> Bool
  func clear()
}

@MainActor
final class AppLockManager: AppLockManaging {
  private enum UnlockResult {
    case unlocked
    case denied
    case requiresReauthentication
  }

  private let graceWindow: TimeInterval
  private let nowProvider: () -> Date
  private let contextFactory: () -> LAContext
  private var backgroundedAt: Date?

  private(set) var isLocked = false

  init(
    graceWindow: TimeInterval = 30,
    nowProvider: @escaping () -> Date = Date.init,
    contextFactory: @escaping () -> LAContext = LAContext.init
  ) {
    self.graceWindow = graceWindow
    self.nowProvider = nowProvider
    self.contextFactory = contextFactory
  }

  func appDidEnterBackground() {
    backgroundedAt = nowProvider()
  }

  func enforceIfNeeded(isAuthenticated: Bool, isEnabled: Bool) async -> AppLockEnforcementResult {
    guard isAuthenticated else {
      clear()
      return .notRequired
    }
    guard isEnabled else {
      isLocked = false
      return .notRequired
    }
    guard shouldRequireUnlock() else {
      return .notRequired
    }

    isLocked = true
    switch await performUnlock(localizedReason: "Unlock Norviq") {
    case .unlocked:
      isLocked = false
      return .unlocked
    case .denied:
      return .locked
    case .requiresReauthentication:
      return .requiresReauthentication
    }
  }

  func authenticateDevice(localizedReason: String) async -> AppDeviceAuthenticationResult {
    switch await performUnlock(localizedReason: localizedReason) {
    case .unlocked:
      return .authenticated
    case .denied:
      return .failed
    case .requiresReauthentication:
      return .unavailable
    }
  }

  func unlock() async -> Bool {
    switch await performUnlock(localizedReason: "Unlock Norviq") {
    case .unlocked:
      isLocked = false
      return true
    case .denied:
      isLocked = true
      return false
    case .requiresReauthentication:
      isLocked = true
      return false
    }
  }

  func clear() {
    isLocked = false
    backgroundedAt = nil
  }

  private func shouldRequireUnlock() -> Bool {
    guard let backgroundedAt else {
      return false
    }
    return nowProvider().timeIntervalSince(backgroundedAt) > graceWindow
  }

  private func performUnlock(localizedReason: String) async -> UnlockResult {
    let context = contextFactory()
    var evaluationError: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
      return .requiresReauthentication
    }

    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: localizedReason
      )
      return success ? .unlocked : .denied
    } catch let laError as LAError {
      switch laError.code {
      case .authenticationFailed, .userCancel, .userFallback, .systemCancel, .appCancel:
        return .denied
      case .biometryLockout:
        return .denied
      case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled, .invalidContext:
        return .requiresReauthentication
      default:
        return .requiresReauthentication
      }
    } catch {
      return .requiresReauthentication
    }
  }
}

enum SecurityCodeError: LocalizedError, Equatable {
  case invalidCode
  case notConfigured
  case verificationFailed
  case randomGenerationFailed

  var errorDescription: String? {
    switch self {
    case .invalidCode:
      return "Enter a 6-digit security code."
    case .notConfigured:
      return "Security Code is not set up."
    case .verificationFailed:
      return "That security code is incorrect."
    case .randomGenerationFailed:
      return "Unable to create a secure Security Code salt."
    }
  }
}

protocol SecurityCodeManaging {
  var isEnabled: Bool { get }
  func setCode(_ code: String) throws
  func verifyCode(_ code: String) throws -> Bool
  func changeCode(currentCode: String, newCode: String) throws
  func removeCode(currentCode: String) throws
}

final class SecurityCodeManager: SecurityCodeManaging {
  private struct StoredCode: Codable, Equatable {
    let salt: String
    let hash: String
  }

  private static let storageKey = "app_security_code_hash"
  private let store: SecureStringStoring

  init(store: SecureStringStoring) {
    self.store = store
  }

  var isEnabled: Bool {
    (try? storedCode()) != nil
  }

  func setCode(_ code: String) throws {
    try validate(code)
    let salt = try makeSalt()
    let stored = StoredCode(salt: salt, hash: hash(code: code, salt: salt))
    let data = try JSONEncoder().encode(stored)
    guard let value = String(data: data, encoding: .utf8) else {
      throw SecureStoreError.invalidEncoding
    }
    try store.setString(value, for: Self.storageKey)
  }

  func verifyCode(_ code: String) throws -> Bool {
    try validate(code)
    guard let stored = try storedCode() else {
      throw SecurityCodeError.notConfigured
    }
    return hash(code: code, salt: stored.salt) == stored.hash
  }

  func changeCode(currentCode: String, newCode: String) throws {
    guard try verifyCode(currentCode) else {
      throw SecurityCodeError.verificationFailed
    }
    try setCode(newCode)
  }

  func removeCode(currentCode: String) throws {
    guard try verifyCode(currentCode) else {
      throw SecurityCodeError.verificationFailed
    }
    try store.removeValue(for: Self.storageKey)
  }

  private func storedCode() throws -> StoredCode? {
    guard let value = try store.string(for: Self.storageKey) else {
      return nil
    }
    guard let data = value.data(using: .utf8) else {
      throw SecureStoreError.invalidEncoding
    }
    return try JSONDecoder().decode(StoredCode.self, from: data)
  }

  private func validate(_ code: String) throws {
    guard code.count == 6, code.allSatisfy(\.isNumber) else {
      throw SecurityCodeError.invalidCode
    }
  }

  private func makeSalt() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
      throw SecurityCodeError.randomGenerationFailed
    }
    return Data(bytes).base64EncodedString()
  }

  private func hash(code: String, salt: String) -> String {
    let input = "\(salt):\(code)"
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
