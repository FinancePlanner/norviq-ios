import Factory
import Foundation

protocol AchievementsServicing: Sendable {
  func list() async throws -> AchievementsResponse
  func unseen() async throws -> [AchievementUnlock]
  func markSeen(_ ids: [String]) async throws
  func setShowcase(_ items: [AchievementShowcaseItem]) async throws -> AchievementsResponse
}

struct DefaultAchievementsService: AchievementsServicing {
  let client: AchievementsHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = AchievementsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func list() async throws -> AchievementsResponse { try await client.list() }
  func unseen() async throws -> [AchievementUnlock] { try await client.unseen() }
  func markSeen(_ ids: [String]) async throws { try await client.markSeen(ids: ids) }
  func setShowcase(_ items: [AchievementShowcaseItem]) async throws -> AchievementsResponse {
    try await client.setShowcase(items: items)
  }
}
