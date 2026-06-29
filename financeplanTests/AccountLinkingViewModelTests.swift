import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AccountLinkingViewModelTests: XCTestCase {
  private final class ServiceMock: AccountLinkingServiceProtocol, @unchecked Sendable {
    var accountsResult: Result<[OAuthLinkedAccount], Error> = .success([])
    var connectResult: Result<OAuthLinkResponse, Error> = .failure(MockError.notConfigured)
    var connectedProviders: [OAuthProviderKind] = []
    var listCalls = 0

    func linkedAccounts() async throws -> [OAuthLinkedAccount] {
      listCalls += 1
      return try accountsResult.get()
    }

    func connect(provider: OAuthProviderKind) async throws -> OAuthLinkResponse {
      connectedProviders.append(provider)
      return try connectResult.get()
    }
  }

  private enum MockError: LocalizedError {
    case notConfigured
    case mismatch

    var errorDescription: String? {
      switch self {
      case .notConfigured:
        return "Not configured."
      case .mismatch:
        return "Provider email must match your account email."
      }
    }
  }

  func testLoadPublishesConnectedAccounts() async {
    let service = ServiceMock()
    service.accountsResult = .success([
      OAuthLinkedAccount(provider: .apple, connected: false),
      OAuthLinkedAccount(provider: .google, connected: true, email: "user@example.com", emailVerified: true),
      OAuthLinkedAccount(provider: .x, connected: false)
    ])
    let viewModel = AccountLinkingViewModel(service: service)

    await viewModel.load()

    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(viewModel.accounts.count, 3)
    XCTAssertEqual(viewModel.accounts.first(where: { $0.provider == .google })?.connected, true)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testConnectRefreshesStatusAndShowsSuccess() async {
    let service = ServiceMock()
    service.accountsResult = .success([
      OAuthLinkedAccount(provider: .google, connected: true, email: "user@example.com", emailVerified: true)
    ])
    service.connectResult = .success(
      OAuthLinkResponse(provider: .google, connected: true, email: "user@example.com", message: "Connected.")
    )
    let viewModel = AccountLinkingViewModel(service: service)

    await viewModel.connect(.google)

    XCTAssertEqual(service.connectedProviders, [.google])
    XCTAssertEqual(service.listCalls, 1)
    XCTAssertEqual(viewModel.successMessage, "Google connected.")
    XCTAssertNil(viewModel.errorMessage)
  }

  func testConnectMismatchSurfacesReadableError() async {
    let service = ServiceMock()
    service.connectResult = .failure(MockError.mismatch)
    let viewModel = AccountLinkingViewModel(service: service)

    await viewModel.connect(.x)

    XCTAssertEqual(viewModel.errorMessage, "Provider email must match your account email.")
    XCTAssertNil(viewModel.successMessage)
  }
}
