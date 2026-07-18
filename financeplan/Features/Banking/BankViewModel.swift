import Factory
import Foundation
import StockPlanShared

@MainActor
@Observable
final class BankViewModel {
  private(set) var connections: [BankConnectionResponse] = []
  private(set) var suggestions: [BankTransactionResponse] = []
  private(set) var isLoading = false
  private(set) var isConnecting = false
  private(set) var busyTransactionIds: Set<String> = []
  var errorMessage: String?

  /// Link token fetched from the backend, consumed by Plaid Link.
  private(set) var pendingLinkToken: String?

  private(set) var institutions: [BankInstitutionResponse] = []
  private(set) var isLoadingInstitutions = false

  private let service: any BankServicing

  init(service: any BankServicing = Container.shared.bankService()) {
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let connectionsTask = service.listConnections()
      async let suggestionsTask = service.listSuggestedTransactions()
      connections = try await connectionsTask
      suggestions = try await suggestionsTask
      errorMessage = nil
    } catch {
      errorMessage = describe(error)
    }
  }

  /// Requests a Plaid link token so the caller can present Plaid Link.
  func beginConnect() async {
    isConnecting = true
    defer { isConnecting = false }
    do {
      let session = try await service.createLinkSession()
      guard let token = session.linkToken else {
        errorMessage = "This bank provider isn't available yet."
        return
      }
      pendingLinkToken = token
    } catch {
      errorMessage = describe(error)
    }
  }

  func clearPendingLinkToken() {
    pendingLinkToken = nil
  }

  func loadInstitutions(country: String) async {
    isLoadingInstitutions = true
    defer { isLoadingInstitutions = false }
    do {
      institutions = try await service.listInstitutions(country: country)
      errorMessage = nil
    } catch {
      errorMessage = describe(error)
      institutions = []
    }
  }

  @MainActor
  func connectGoCardless(institutionId: String) async {
    isConnecting = true
    defer { isConnecting = false }
    do {
      try await service.connectGoCardless(institutionId: institutionId)
      await load()
    } catch {
      errorMessage = describe(error)
    }
  }

  /// Completes the Plaid Link flow by exchanging the public token.
  func completeConnect(publicToken: String, institutionId: String?, institutionName: String?) async {
    isConnecting = true
    defer { isConnecting = false }
    do {
      _ = try await service.exchange(publicToken: publicToken, institutionId: institutionId, institutionName: institutionName)
      await load()
    } catch {
      errorMessage = describe(error)
    }
  }

  func disconnect(_ connection: BankConnectionResponse) async {
    do {
      try await service.disconnect(connectionId: connection.id)
      await load()
    } catch {
      errorMessage = describe(error)
    }
  }

  func sync(_ connection: BankConnectionResponse) async {
    do {
      _ = try await service.sync(connectionId: connection.id)
      await load()
    } catch {
      errorMessage = describe(error)
    }
  }

  func importTransaction(_ transaction: BankTransactionResponse, pillar: BudgetPillar) async {
    busyTransactionIds.insert(transaction.id)
    defer { busyTransactionIds.remove(transaction.id) }
    do {
      _ = try await service.importTransaction(transactionId: transaction.id, pillar: pillar, categoryId: nil, titleOverride: nil)
      suggestions.removeAll { $0.id == transaction.id }
    } catch {
      errorMessage = describe(error)
    }
  }

  func dismiss(_ transaction: BankTransactionResponse) async {
    busyTransactionIds.insert(transaction.id)
    defer { busyTransactionIds.remove(transaction.id) }
    do {
      try await service.dismiss(transactionId: transaction.id)
      suggestions.removeAll { $0.id == transaction.id }
    } catch {
      errorMessage = describe(error)
    }
  }

  private func describe(_ error: any Swift.Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
  }
}
