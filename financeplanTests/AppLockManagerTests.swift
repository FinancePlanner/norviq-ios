import LocalAuthentication
import XCTest
@testable import financeplan

@MainActor
final class AppLockManagerTests: XCTestCase {
  private final class SecureStoreStub: SecureStringStoring {
    var values: [String: String] = [:]
    var writeError: Error?

    func string(for key: String) throws -> String? {
      values[key]
    }

    func setString(_ value: String, for key: String) throws {
      if let writeError {
        throw writeError
      }
      values[key] = value
    }

    func removeValue(for key: String) throws {
      values.removeValue(forKey: key)
    }
  }

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

  func testAuthenticateDevice_ReturnsAuthenticatedWhenPolicySucceeds() async {
    let context = ContextStub()
    context.canEvaluate = true
    context.evaluateResult = true
    let manager = AppLockManager(contextFactory: { context })

    let result = await manager.authenticateDevice(localizedReason: "Enable Face ID")

    XCTAssertEqual(result, .authenticated)
  }

  func testSecurityCodeManager_SetsAndVerifiesCode() throws {
    let store = SecureStoreStub()
    let manager = SecurityCodeManager(store: store)

    try manager.setCode("123456")

    XCTAssertTrue(manager.isEnabled)
    XCTAssertTrue(try manager.verifyCode("123456"))
    XCTAssertFalse(try manager.verifyCode("654321"))
  }

  func testSecurityCodeManager_RejectsInvalidCode() {
    let store = SecureStoreStub()
    let manager = SecurityCodeManager(store: store)

    XCTAssertThrowsError(try manager.setCode("12345"))
    XCTAssertFalse(manager.isEnabled)
  }

  func testSecurityCodeManager_ChangesAndRemovesCode() throws {
    let store = SecureStoreStub()
    let manager = SecurityCodeManager(store: store)

    try manager.setCode("123456")
    try manager.changeCode(currentCode: "123456", newCode: "222222")

    XCTAssertFalse(try manager.verifyCode("123456"))
    XCTAssertTrue(try manager.verifyCode("222222"))

    try manager.removeCode(currentCode: "222222")
    XCTAssertFalse(manager.isEnabled)
  }
}
