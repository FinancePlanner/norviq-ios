import Factory
import Foundation
import StockPlanShared

protocol PilotsServicing: Sendable {
  func pilots() async throws -> [PilotSummary]
  func pilot(slug: String) async throws -> PilotDetail
  func follows() async throws -> [PilotFollowResponse]
  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse
  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse
  func stopFollowing(followId: String) async throws
  func events(followId: String) async throws -> [PilotFollowEventResponse]
  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse]
  /// The viewer's watchlists, for picking an existing (empty) one as a target.
  func watchlists() async throws -> [WatchlistListDTOResponse]
}

struct DefaultPilotsService: PilotsServicing {
  let client: PilotsHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = PilotsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func pilots() async throws -> [PilotSummary] { try await client.pilots() }
  func pilot(slug: String) async throws -> PilotDetail { try await client.pilot(slug: slug) }
  func follows() async throws -> [PilotFollowResponse] { try await client.follows() }
  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    try await client.follow(request, idempotencyKey: idempotencyKey)
  }
  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    try await client.setStatus(status, followId: followId)
  }
  func stopFollowing(followId: String) async throws { try await client.stopFollowing(followId: followId) }
  func events(followId: String) async throws -> [PilotFollowEventResponse] { try await client.events(followId: followId) }
  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] { try await client.snapshots(followId: followId) }
  func watchlists() async throws -> [WatchlistListDTOResponse] {
    try await Container.shared.stockService().fetchWatchlistLists()
  }
}
