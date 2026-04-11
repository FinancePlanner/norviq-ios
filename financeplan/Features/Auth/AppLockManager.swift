import Foundation
import LocalAuthentication

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
    switch await performUnlock() {
    case .unlocked:
      isLocked = false
      return .unlocked
    case .denied:
      return .locked
    case .requiresReauthentication:
      return .requiresReauthentication
    }
  }

  func unlock() async -> Bool {
    switch await performUnlock() {
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

  private func performUnlock() async -> UnlockResult {
    let context = contextFactory()
    var evaluationError: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
      return .requiresReauthentication
    }

    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: "Unlock Norviqa"
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
