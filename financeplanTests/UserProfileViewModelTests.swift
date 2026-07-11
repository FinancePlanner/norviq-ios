import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class UserProfileViewModelTests: XCTestCase {

  /// Configurable mock conforming to `UserProfileServiceProtocol`.
  private final class MockService: UserProfileServiceProtocol, @unchecked Sendable {
    var deleteAccountError: Error?
    private(set) var deleteAccountCallCount = 0

    struct StubError: LocalizedError {
      let errorDescription: String?
    }

    func fetchProfile() async throws -> UserProfile {
      UserProfile(id: "u", email: "u@example.com", username: "u")
    }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile { profile }
    func updateUsername(_ username: String) async throws -> UserProfile {
      UserProfile(id: "u", email: "u@example.com", username: username)
    }
    func updateEmail(_ email: String) async throws -> UserProfile {
      UserProfile(id: "u", email: email, username: "u")
    }
    func updatePassword(current: String, new: String) async throws {}

    func deleteAccount() async throws {
      deleteAccountCallCount += 1
      if let deleteAccountError { throw deleteAccountError }
    }
  }

  func testDeleteAccount_Success_ReturnsTrueAndClearsError() async {
    let mock = MockService()
    let viewModel = UserProfileViewModel(service: mock)

    let result = await viewModel.deleteAccount()

    XCTAssertTrue(result)
    XCTAssertEqual(mock.deleteAccountCallCount, 1)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testDeleteAccount_Failure_ReturnsFalseAndSetsError() async {
    let mock = MockService()
    mock.deleteAccountError = MockService.StubError(errorDescription: "Server unavailable")
    let viewModel = UserProfileViewModel(service: mock)

    let result = await viewModel.deleteAccount()

    XCTAssertFalse(result)
    XCTAssertEqual(viewModel.errorMessage, "Server unavailable")
    XCTAssertFalse(viewModel.isLoading)
  }
}
