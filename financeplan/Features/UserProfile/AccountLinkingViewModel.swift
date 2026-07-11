import Factory
import Foundation
import Observation
import StockPlanShared

@Observable @MainActor
final class AccountLinkingViewModel {
  private(set) var accounts: [OAuthLinkedAccount] = []
  private(set) var isLoading = false
  private(set) var activeProvider: OAuthProviderKind?
  private(set) var errorMessage: String?
  private(set) var successMessage: String?

  private let service: AccountLinkingServiceProtocol

  init(service: AccountLinkingServiceProtocol) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.accountLinkingService())
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      accounts = try await service.linkedAccounts()
    } catch {
      errorMessage = readableMessage(for: error, fallback: "Failed to load connected accounts.")
    }
  }

  func connect(_ provider: OAuthProviderKind) async {
    guard activeProvider == nil else { return }
    activeProvider = provider
    errorMessage = nil
    successMessage = nil
    defer { activeProvider = nil }

    do {
      _ = try await service.connect(provider: provider)
      successMessage = "\(label(for: provider)) connected."
      await load()
    } catch {
      errorMessage = readableMessage(for: error, fallback: "Failed to connect \(label(for: provider)).")
    }
  }

  func account(for provider: OAuthProviderKind) -> OAuthLinkedAccount {
    accounts.first(where: { $0.provider == provider }) ?? OAuthLinkedAccount(provider: provider, connected: false)
  }

  func label(for provider: OAuthProviderKind) -> String {
    switch provider {
    case .apple: return "Apple"
    case .google: return "Google"
    case .x: return "X"
    @unknown default: return provider.rawValue
    }
  }

  private func readableMessage(for error: Error, fallback: String) -> String {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : message
  }
}
