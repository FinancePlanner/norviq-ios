import Foundation
import StockPlanShared

protocol TerminalPositionsServicing: Sendable {
  func list(ticker: String?) async throws -> TerminalPositionsListResponse
  func create(_ request: TerminalPositionCreateRequest) async throws -> TerminalPositionResponse
  func update(id: String, _ request: TerminalPositionUpdateRequest) async throws -> TerminalPositionResponse
  func delete(id: String) async throws
  func duplicate(id: String) async throws -> TerminalPositionResponse
  func reorder(ids: [String]) async throws -> TerminalPositionsListResponse
  func summary() async throws -> TerminalPositionsSummaryResponse
  func autobuys() async throws -> AutobuysListResponse
  func createAutobuy(_ request: AutobuyCreateRequest) async throws -> AutobuyResponse
  func updateAutobuy(id: String, _ request: AutobuyUpdateRequest) async throws -> AutobuyResponse
  func deleteAutobuy(id: String) async throws
  /// Pro. A suggestion with sources; nothing is written.
  func shareFacts(ticker: String) async throws -> ShareFactsSuggestion
  /// Pro. A suggestion with sources; nothing is written.
  func suggestScenario(ticker: String, horizonYears: Int?) async throws -> TerminalScenarioSuggestion
}

final class TerminalPositionsService: TerminalPositionsServicing, Sendable {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: any HTTPClientSession

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: any HTTPClientSession = URLSession.shared
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
  }

  func list(ticker: String?) async throws -> TerminalPositionsListResponse {
    try await authenticated { try await $0.list(ticker: ticker) }
  }

  func create(_ request: TerminalPositionCreateRequest) async throws -> TerminalPositionResponse {
    try await authenticated { try await $0.create(request) }
  }

  func update(id: String, _ request: TerminalPositionUpdateRequest) async throws -> TerminalPositionResponse {
    try await authenticated { try await $0.update(id: id, request) }
  }

  func delete(id: String) async throws {
    try await authenticated { try await $0.delete(id: id) }
  }

  func duplicate(id: String) async throws -> TerminalPositionResponse {
    try await authenticated { try await $0.duplicate(id: id) }
  }

  func reorder(ids: [String]) async throws -> TerminalPositionsListResponse {
    try await authenticated { try await $0.reorder(ids: ids) }
  }

  func summary() async throws -> TerminalPositionsSummaryResponse {
    try await authenticated { try await $0.summary() }
  }

  func autobuys() async throws -> AutobuysListResponse {
    try await authenticated { try await $0.autobuys() }
  }

  func createAutobuy(_ request: AutobuyCreateRequest) async throws -> AutobuyResponse {
    try await authenticated { try await $0.createAutobuy(request) }
  }

  func updateAutobuy(id: String, _ request: AutobuyUpdateRequest) async throws -> AutobuyResponse {
    try await authenticated { try await $0.updateAutobuy(id: id, request) }
  }

  func deleteAutobuy(id: String) async throws {
    try await authenticated { try await $0.deleteAutobuy(id: id) }
  }

  func shareFacts(ticker: String) async throws -> ShareFactsSuggestion {
    try await authenticated { try await $0.shareFacts(ticker: ticker) }
  }

  func suggestScenario(ticker: String, horizonYears: Int?) async throws -> TerminalScenarioSuggestion {
    try await authenticated { try await $0.suggestScenario(ticker: ticker, horizonYears: horizonYears) }
  }

  private func authenticated<T: Sendable>(
    _ operation: (TerminalPositionsHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      return try await operation(client())
    } catch let error as TerminalPositionsHTTPClient.Error where error.isUnauthorized {
      do {
        return try await operation(client(forceRefresh: true))
      } catch let retry as TerminalPositionsHTTPClient.Error where retry.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retry
      }
    }
  }

  private func client(forceRefresh: Bool = false) async throws -> TerminalPositionsHTTPClient {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()
    guard let token, !token.isEmpty else { throw AuthSessionError.notAuthenticated }
    return TerminalPositionsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }
}
