import Foundation
import StockPlanShared
@testable import financeplan

final class MockPilotsService: PilotsServicing, @unchecked Sendable {
  var pilotsResult: Result<[PilotSummary], Error> = .success([.fixture()])
  var detailResult: Result<PilotDetail, Error> = .success(.fixture())
  var followsResult: Result<[PilotFollowResponse], Error> = .success([])
  var followResult: Result<PilotFollowResponse, Error> = .success(.fixture())
  var statusError: Error?
  var stopError: Error?
  var eventsResult: Result<[PilotFollowEventResponse], Error> = .success([])
  var snapshotsResult: Result<[PilotFollowSnapshotResponse], Error> = .success([])
  var watchlistsResult: Result<[WatchlistListDTOResponse], Error> = .success([])

  private(set) var followRequests: [PilotFollowCreateRequest] = []
  private(set) var idempotencyKeys: [String] = []
  private(set) var statusRequests: [PilotFollowStatus] = []
  private(set) var stoppedFollowIds: [String] = []
  private(set) var snapshotCalls = 0

  func pilots() async throws -> [PilotSummary] { try pilotsResult.get() }
  func pilot(slug: String) async throws -> PilotDetail { try detailResult.get() }
  func follows() async throws -> [PilotFollowResponse] { try followsResult.get() }

  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    followRequests.append(request)
    idempotencyKeys.append(idempotencyKey)
    return try followResult.get()
  }

  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    statusRequests.append(status)
    if let statusError { throw statusError }
    return .fixture(id: followId, status: status)
  }

  func stopFollowing(followId: String) async throws {
    if let stopError { throw stopError }
    stoppedFollowIds.append(followId)
  }

  func events(followId: String) async throws -> [PilotFollowEventResponse] { try eventsResult.get() }

  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] {
    snapshotCalls += 1
    return try snapshotsResult.get()
  }

  func watchlists() async throws -> [WatchlistListDTOResponse] { try watchlistsResult.get() }
}

extension PilotSummary {
  static func fixture(
    slug: String = "nancy-pelosi",
    displayName: String = "Nancy Pelosi",
    kind: PilotKind = .politician,
    holdingsCount: Int = 12
  ) -> PilotSummary {
    PilotSummary(
      slug: slug,
      displayName: displayName,
      kind: kind,
      chamber: kind == .politician ? "house" : nil,
      updatedAt: "2026-09-30T12:00:00Z",
      holdingsCount: holdingsCount
    )
  }
}

extension PilotDetail {
  static func fixture(pilot: PilotSummary = .fixture(), skippedPuts: Int = 0) -> PilotDetail {
    PilotDetail(
      pilot: pilot,
      weights: [PilotWeight(symbol: "NVDA", weight: 0.6), PilotWeight(symbol: "AAPL", weight: 0.4)],
      skippedPuts: skippedPuts,
      recentDisclosures: [
        PilotDisclosureItem(
          symbol: "NVDA", side: "buy", instrument: "call", transactionDate: "2026-09-14",
          disclosureDate: "2026-09-28", amountMin: 1001, amountMax: 15000, period: nil
        )
      ],
      lagNote: "Congressional trades are disclosed up to 45 days after they happen."
    )
  }
}

extension PilotFollowResponse {
  static func fixture(
    id: String = "11111111-1111-1111-1111-111111111111",
    pilot: PilotSummary = .fixture(),
    targetKind: PilotFollowTargetKind = .portfolio,
    portfolioListId: String = "22222222-2222-2222-2222-222222222222",
    startingCapital: Double = 10_000,
    status: PilotFollowStatus = .active,
    appliedVersion: Int = 1
  ) -> PilotFollowResponse {
    PilotFollowResponse(
      id: id,
      pilot: pilot,
      targetKind: targetKind,
      portfolioListId: targetKind == .portfolio ? portfolioListId : nil,
      watchlistListId: targetKind == .watchlist ? "33333333-3333-3333-3333-333333333333" : nil,
      startingCapital: targetKind == .portfolio ? startingCapital : nil,
      currency: "USD",
      status: status,
      appliedVersion: appliedVersion,
      createdAt: "2026-10-01T09:00:00Z"
    )
  }
}

extension PilotFollowEventResponse {
  static func fixture(
    id: String = "e1",
    kind: String = "buy",
    symbol: String = "NVDA",
    quantity: Double? = 12.5,
    price: Double? = 123.45,
    note: String? = nil
  ) -> PilotFollowEventResponse {
    PilotFollowEventResponse(
      id: id, bookVersion: 1, kind: kind, symbol: symbol, quantity: quantity,
      price: price, pricedAt: "2026-09-30T14:00:00Z", note: note
    )
  }
}
