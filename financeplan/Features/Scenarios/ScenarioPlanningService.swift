import Foundation

struct ScenarioCatalogPayload: Decodable, Sendable {
  struct Item: Decodable, Identifiable, Sendable { let id: String; let name: String; let startDate: String; let endDate: String }
  let version: String; let historicalScenarios: [Item]
}

struct ScenarioResultPayload: Decodable, Sendable {
  struct Point: Decodable, Identifiable, Sendable {
    let elapsedMonths: Int; let value: Double; var id: Int { elapsedMonths }
    enum CodingKeys: String, CodingKey { case elapsedMonths = "elapsed_months"; case value }
  }
  let timeline: [Point]?; let maximumDrawdown: Double?; let goalProbability: Double?; let expectedShortfall: Double?
  enum CodingKeys: String, CodingKey { case timeline; case maximumDrawdown = "maximum_drawdown"; case goalProbability = "goal_probability"; case expectedShortfall = "expected_shortfall" }
}

struct ScenarioRunSummary: Decodable, Identifiable, Sendable {
  let id: UUID; let state: String; let progress: Double; let engineVersion: String; let errorMessage: String?; let result: ScenarioResultPayload?
}
struct ScenarioPortfolio: Decodable, Identifiable, Sendable { let id: UUID; let name: String; let isDefault: Bool }
struct ScenarioGoal: Decodable, Identifiable, Sendable { let id: UUID; let name: String }
private struct ScenarioResource: Decodable { let id: UUID }
private struct EmptyResponse: Decodable {}

enum ScenarioBuilderKind: String, CaseIterable, Identifiable, Sendable {
  case historical, custom, monteCarlo = "monte_carlo"; var id: String { rawValue }
  var title: String { switch self { case .historical: "Historical"; case .custom: "Custom"; case .monteCarlo: "Monte Carlo" } }
}
struct ScenarioRunRequest: Sendable {
  let name: String; let portfolioID: UUID; let goalID: UUID?; let kind: ScenarioBuilderKind; let catalogID: String
  let shock: Double; let horizonMonths: Int; let pathCount: Int; let distribution: String; let seed: Int64?; let save: Bool
}

protocol ScenarioPlanningServiceProtocol: Sendable {
  func catalog() async throws -> ScenarioCatalogPayload; func runs() async throws -> [ScenarioRunSummary]
  func portfolios() async throws -> [ScenarioPortfolio]; func goals() async throws -> [ScenarioGoal]
  func createRun(_ input: ScenarioRunRequest) async throws -> ScenarioRunSummary
  func run(id: UUID) async throws -> ScenarioRunSummary; func cancel(runID: UUID) async throws
}

final class ScenarioPlanningService: ScenarioPlanningServiceProtocol, @unchecked Sendable {
  private let environment: AppEnvironmentManager; private let auth: AuthSessionManaging; private let session: URLSession
  init(environment: AppEnvironmentManager, auth: AuthSessionManaging, session: URLSession = .shared) { self.environment = environment; self.auth = auth; self.session = session }
  func catalog() async throws -> ScenarioCatalogPayload { try await send("v1/scenarios/catalog") }
  func runs() async throws -> [ScenarioRunSummary] { try await send("v1/scenario-runs") }
  func portfolios() async throws -> [ScenarioPortfolio] { try await send("v1/portfolio-lists") }
  func goals() async throws -> [ScenarioGoal] { try await send("v1/financial-goals") }
  func run(id: UUID) async throws -> ScenarioRunSummary { try await send("v1/scenario-runs/\(id)") }
  func cancel(runID: UUID) async throws { let _: EmptyResponse = try await send("v1/scenario-runs/\(runID)", method: "DELETE") }

  func createRun(_ input: ScenarioRunRequest) async throws -> ScenarioRunSummary {
    let snapshot: ScenarioResource = try await send("v1/portfolio/scenario-snapshots", method: "POST", body: ["portfolioListId": input.portfolioID.uuidString, "baseCurrency": "USD"])
    let configuration: [String: Any]
    switch input.kind {
    case .historical: configuration = ["catalogId": input.catalogID]
    case .custom: configuration = ["asset_class_shocks": [["target": "stock", "percentage": input.shock]], "horizon_months": min(input.horizonMonths, 120), "recovery": "linear"]
    case .monteCarlo: configuration = ["path_count": min(input.pathCount, 50_000), "horizon_months": min(input.horizonMonths, 600), "distribution": input.distribution]
    }
    var body: [String: Any] = ["name": input.name, "portfolioListId": input.portfolioID.uuidString, "kind": input.kind.rawValue, "configuration": configuration, "isSaved": input.save]
    if let goalID = input.goalID { body["financialGoalId"] = goalID.uuidString }
    let scenario: ScenarioResource = try await send("v1/scenarios", method: "POST", body: body)
    var runBody: [String: Any] = ["snapshotId": snapshot.id.uuidString]; if let seed = input.seed { runBody["seed"] = seed }
    return try await send("v1/scenarios/\(scenario.id)/runs", method: "POST", body: runBody)
  }

  private func send<Response: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Response {
    guard let token = try await auth.validAccessToken() else { throw AuthSessionError.notAuthenticated }
    var request = URLRequest(url: environment.current.apiBaseUrl.appending(path: path)); request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body { request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body) }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    if Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}
