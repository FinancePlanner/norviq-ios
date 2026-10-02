import AnyAPI
import Foundation
import StockPlanShared

// Pilot follows. Contract: StockPlanShared PilotDTOs; routes in the backend's
// Pilots/PilotController.swift. Every route returns 404 while PILOTS_ENABLED is off.

private nonisolated func pilotParameters(_ payload: some Encodable) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(payload)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

nonisolated struct ListPilotsEndpoint: Endpoint {
  typealias Response = [PilotSummary]
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilots" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPilotEndpoint: Endpoint {
  typealias Response = PilotDetail
  let slug: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilots/\(slug)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowsEndpoint: Endpoint {
  typealias Response = [PilotFollowResponse]
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

/// The backend caches a successful response per `Idempotency-Key` for 24h, so
/// a retry after a dropped response replays the first follow instead of
/// creating a second one.
nonisolated struct CreatePilotFollowEndpoint: Endpoint {
  typealias Response = PilotFollowResponse
  let payload: PilotFollowCreateRequest
  let idempotencyKey: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/pilot-follows" }
  var decoder: JSONDecoder { .stockPlanShared }
  // Must be `HTTPHeaders` (AnyAPI's requirement); a tuple array compiles but is ignored.
  var headers: HTTPHeaders { ["Idempotency-Key": idempotencyKey] }
  func asParameters() throws -> Parameters { try pilotParameters(payload) }
}

nonisolated struct UpdatePilotFollowEndpoint: Endpoint {
  typealias Response = PilotFollowResponse
  let followId: String
  let payload: PilotFollowUpdateRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/pilot-follows/\(followId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try pilotParameters(payload) }
}

nonisolated struct DeletePilotFollowEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let followId: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/pilot-follows/\(followId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowEventsEndpoint: Endpoint {
  typealias Response = [PilotFollowEventResponse]
  let followId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows/\(followId)/events" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowSnapshotsEndpoint: Endpoint {
  typealias Response = [PilotFollowSnapshotResponse]
  let followId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows/\(followId)/snapshots" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}
