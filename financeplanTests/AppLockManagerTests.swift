import LocalAuthentication
import XCTest
@testable import financeplan

@MainActor
final class AppLockManagerTests: XCTestCase {
  private final class ContextStub: LAContext {
    var canEvaluate = true
    var evaluateResult = true
    var evaluateError: Error?

    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
      if !canEvaluate {
        error?.pointee = LAError(.passcodeNotSet) as NSError
      }
      return canEvaluate
    }

    override func evaluatePolicy(
      _ policy: LAPolicy,
      localizedReason: String
    ) async throws -> Bool {
      if let evaluateError {
        throw evaluateError
      }
      return evaluateResult
    }
  }

  func testEnforceIfNeeded_DoesNotLockWithinGraceWindow() async {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    let context = ContextStub()
    let manager = AppLockManager(
      graceWindow: 30,
      nowProvider: { now },
      contextFactory: { context }
    )

    manager.appDidEnterBackground()
    now = now.addingTimeInterval(10)

    let result = await manager.enforceIfNeeded(isAuthenticated: true, isEnabled: true)
    XCTAssertEqual(result, .notRequired)
    XCTAssertFalse(manager.isLocked)
  }

  func testEnforceIfNeeded_UnlocksWhenAuthenticationSucceeds() async {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    let context = ContextStub()
    context.canEvaluate = true
    context.evaluateResult = true

    let manager = AppLockManager(
      graceWindow: 30,
      nowProvider: { now },
      contextFactory: { context }
    )

    manager.appDidEnterBackground()
    now = now.addingTimeInterval(45)

    let result = await manager.enforceIfNeeded(isAuthenticated: true, isEnabled: true)
    XCTAssertEqual(result, .unlocked)
    XCTAssertFalse(manager.isLocked)
  }

  func testEnforceIfNeeded_RequiresReauthenticationWhenPolicyUnavailable() async {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    let context = ContextStub()
    context.canEvaluate = false

    let manager = AppLockManager(
      graceWindow: 30,
      nowProvider: { now },
      contextFactory: { context }
    )

    manager.appDidEnterBackground()
    now = now.addingTimeInterval(45)

    let result = await manager.enforceIfNeeded(isAuthenticated: true, isEnabled: true)
    XCTAssertEqual(result, .requiresReauthentication)
    XCTAssertTrue(manager.isLocked)
  }
}
