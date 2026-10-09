import AnyAPI
import Foundation
import StockPlanShared

// Terminal position sizing. Contract: norviq-backend
// docs/superpowers/plans/2026-10-09-terminal-contract.md. Routes live in the
// backend's TerminalPositions/ module, all under /v1.

/// Encodes a request body the way the rest of the app does: snake_case keys,
/// nil fields left out (a PATCH treats a missing key as "leave it").
private nonisolated func terminalParameters(_ payload: some Encodable) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(payload)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

nonisolated struct ListTerminalPositionsEndpoint: Endpoint {
  typealias Response = TerminalPositionsListResponse
  let ticker: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/terminal-positions" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    guard let ticker, !ticker.isEmpty else { return [:] }
    return ["ticker": ticker]
  }
}

nonisolated struct CreateTerminalPositionEndpoint: Endpoint {
  typealias Response = TerminalPositionResponse
  let payload: TerminalPositionCreateRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/terminal-positions" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

nonisolated struct UpdateTerminalPositionEndpoint: Endpoint {
  typealias Response = TerminalPositionResponse
  let id: String
  let payload: TerminalPositionUpdateRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/terminal-positions/\(id)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

nonisolated struct DeleteTerminalPositionEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let id: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/terminal-positions/\(id)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct DuplicateTerminalPositionEndpoint: Endpoint {
  typealias Response = TerminalPositionResponse
  let id: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/terminal-positions/\(id)/duplicate" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ReorderTerminalPositionsEndpoint: Endpoint {
  typealias Response = TerminalPositionsListResponse
  let payload: TerminalPositionOrderRequest
  var method: HTTPMethod { .put }
  var path: String { "/v1/terminal-positions/order" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

nonisolated struct TerminalPositionsSummaryEndpoint: Endpoint {
  typealias Response = TerminalPositionsSummaryResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/terminal-positions/summary" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListAutobuysEndpoint: Endpoint {
  typealias Response = AutobuysListResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/autobuys" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateAutobuyEndpoint: Endpoint {
  typealias Response = AutobuyResponse
  let payload: AutobuyCreateRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/autobuys" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

nonisolated struct UpdateAutobuyEndpoint: Endpoint {
  typealias Response = AutobuyResponse
  let id: String
  let payload: AutobuyUpdateRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/autobuys/\(id)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

nonisolated struct DeleteAutobuyEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let id: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/autobuys/\(id)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

/// Pro. Suggests only; the server never writes from this route.
nonisolated struct ShareFactsEndpoint: Endpoint {
  typealias Response = ShareFactsSuggestion
  let payload: ShareFactsRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/terminal-positions/ai/share-facts" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}

/// Pro. Suggests only; the server never writes from this route.
nonisolated struct TerminalScenarioSuggestionEndpoint: Endpoint {
  typealias Response = TerminalScenarioSuggestion
  let payload: TerminalScenarioSuggestionRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/terminal-positions/ai/scenario" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try terminalParameters(payload) }
}
