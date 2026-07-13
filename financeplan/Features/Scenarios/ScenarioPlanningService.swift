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
  struct Band: Decodable, Identifiable, Sendable {
    let elapsedMonths: Int; let p10: Double; let p25: Double; let p50: Double; let p75: Double; let p90: Double
    var id: Int { elapsedMonths }
    enum CodingKeys: String, CodingKey { case elapsedMonths = "elapsed_months"; case p10, p25, p50, p75, p90 }
  }
  let timeline: [Point]?; let percentileBands: [Band]?; let maximumDrawdown: Double?; let goalProbability: Double?; let expectedShortfall: Double?
  enum CodingKeys: String, CodingKey {
    case timeline; case percentileBands = "percentile_bands"; case maximumDrawdown = "maximum_drawdown"
    case goalProbability = "goal_probability"; case expectedShortfall = "expected_shortfall"
  }
}

struct ScenarioRunSummary: Decodable, Identifiable, Sendable {
  let id: UUID; let state: String; let progress: Double; let engineVersion: String; let errorMessage: String?; let result: ScenarioResultPayload?
}
struct ScenarioPortfolio: Decodable, Identifiable, Sendable { let id: UUID; let name: String; let isDefault: Bool }
struct ScenarioGoal: Decodable, Identifiable, Sendable {
  let id: UUID; let name: String; let portfolioListId: UUID?; let targetAmount: Double?; let targetDate: Date?; let baseCurrency: String?
  let monthlyContribution: Double?; let annualContributionGrowth: Double?; let inflationAssumption: Double?
}
struct ScenarioHolding: Decodable, Identifiable, Sendable { let id: UUID; let symbol: String; let category: String }
struct ScenarioRiskProfile: Decodable, Identifiable, Sendable {
  let id: UUID; let holdingId: UUID; let assetCategory: String; let sector: String?; let region: String?; let benchmarkProxy: String?
  let manualValue: Double?; let duration: Double?; let convexity: Double?
}
indirect enum ScenarioJSONValue: Codable, Sendable, CustomStringConvertible {
  case object([String: ScenarioJSONValue]), array([ScenarioJSONValue]), string(String), number(Double), bool(Bool), null
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() { self = .null }
    else if let value = try? container.decode([String: ScenarioJSONValue].self) { self = .object(value) }
    else if let value = try? container.decode([ScenarioJSONValue].self) { self = .array(value) }
    else if let value = try? container.decode(Bool.self) { self = .bool(value) }
    else if let value = try? container.decode(Double.self) { self = .number(value) }
    else { self = .string(try container.decode(String.self)) }
  }
  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self { case .object(let value): try container.encode(value); case .array(let value): try container.encode(value); case .string(let value): try container.encode(value); case .number(let value): try container.encode(value); case .bool(let value): try container.encode(value); case .null: try container.encodeNil() }
  }
  var description: String {
    guard let data = try? JSONEncoder().encode(self),
          let object = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    else { return "Unavailable" }
    return String(decoding: pretty, as: UTF8.self)
  }
}
struct ScenarioSnapshotPreview: Decodable, Identifiable, Sendable {
  let id: UUID; let payload: ScenarioJSONValue?; let warnings: ScenarioJSONValue?
}
private struct ScenarioResource: Decodable { let id: UUID }
private struct EmptyResponse: Decodable {}

enum ScenarioBuilderKind: String, CaseIterable, Identifiable, Sendable {
  case historical, custom, monteCarlo = "monte_carlo"; var id: String { rawValue }
  var title: String { switch self { case .historical: "Historical"; case .custom: "Custom"; case .monteCarlo: "Monte Carlo" } }
}

enum ScenarioMultiAssetValidationError: LocalizedError, Equatable {
  case incomplete, invalidJSON, invalidDimensions, invalidWeight, invalidReturn, invalidCovariance

  var errorDescription: String? {
    switch self {
    case .incomplete: "Provide weights, annual returns, and covariance together."
    case .invalidJSON: "Multi-asset assumptions must be valid JSON arrays."
    case .invalidDimensions: "Use 2–50 assets and a matching square covariance matrix."
    case .invalidWeight: "Asset weights must be between 0 and 1 and sum to approximately 1."
    case .invalidReturn: "Annual returns must be finite values between -1 and 10."
    case .invalidCovariance: "Covariance values must be finite, symmetric, and have non-negative diagonal values."
    }
  }
}

func parseScenarioMultiAssetAssumptions(
  weights: String,
  annualReturns: String,
  covariance: String
) throws -> (weights: [Double], annualReturns: [Double], covariance: [[Double]]) {
  let values = [weights, annualReturns, covariance].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  if values.allSatisfy(\.isEmpty) { return ([], [], []) }
  guard values.allSatisfy({ !$0.isEmpty }) else { throw ScenarioMultiAssetValidationError.incomplete }

  let decoder = JSONDecoder()
  guard let decodedWeights = try? decoder.decode([Double].self, from: Data(values[0].utf8)),
        let decodedReturns = try? decoder.decode([Double].self, from: Data(values[1].utf8)),
        let decodedCovariance = try? decoder.decode([[Double]].self, from: Data(values[2].utf8))
  else { throw ScenarioMultiAssetValidationError.invalidJSON }

  let count = decodedWeights.count
  guard (2...50).contains(count), decodedReturns.count == count,
        decodedCovariance.count == count, decodedCovariance.allSatisfy({ $0.count == count })
  else { throw ScenarioMultiAssetValidationError.invalidDimensions }
  guard decodedWeights.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
        abs(decodedWeights.reduce(0, +) - 1) <= 0.001
  else { throw ScenarioMultiAssetValidationError.invalidWeight }
  guard decodedReturns.allSatisfy({ $0.isFinite && (-1...10).contains($0) })
  else { throw ScenarioMultiAssetValidationError.invalidReturn }
  for row in 0..<count {
    guard decodedCovariance[row].allSatisfy(\.isFinite), decodedCovariance[row][row] >= 0 else {
      throw ScenarioMultiAssetValidationError.invalidCovariance
    }
    for column in 0..<count where abs(decodedCovariance[row][column] - decodedCovariance[column][row]) > 0.000_001 {
      throw ScenarioMultiAssetValidationError.invalidCovariance
    }
  }
  return (decodedWeights, decodedReturns, decodedCovariance)
}

struct ScenarioRunRequest: Sendable {
  let name: String; let portfolioID: UUID; let goalID: UUID?; let kind: ScenarioBuilderKind; let catalogID: String
  let shock: Double; let horizonMonths: Int; let pathCount: Int; let distribution: String; let seed: Int64?; let save: Bool
  let assetWeights: [Double]; let assetAnnualReturns: [Double]; let annualCovariance: [[Double]]
  init(name: String, portfolioID: UUID, goalID: UUID?, kind: ScenarioBuilderKind, catalogID: String, shock: Double,
       horizonMonths: Int, pathCount: Int, distribution: String, seed: Int64?, save: Bool,
       assetWeights: [Double] = [], assetAnnualReturns: [Double] = [], annualCovariance: [[Double]] = []) {
    self.name = name; self.portfolioID = portfolioID; self.goalID = goalID; self.kind = kind; self.catalogID = catalogID
    self.shock = shock; self.horizonMonths = horizonMonths; self.pathCount = pathCount; self.distribution = distribution
    self.seed = seed; self.save = save; self.assetWeights = assetWeights; self.assetAnnualReturns = assetAnnualReturns
    self.annualCovariance = annualCovariance
  }
}

protocol ScenarioPlanningServiceProtocol: Sendable {
  func catalog() async throws -> ScenarioCatalogPayload; func runs() async throws -> [ScenarioRunSummary]
  func portfolios() async throws -> [ScenarioPortfolio]; func goals() async throws -> [ScenarioGoal]
  func captureSnapshot(portfolioID: UUID) async throws -> ScenarioSnapshotPreview
  func holdings(portfolioIDs: [UUID]) async throws -> [ScenarioHolding]; func riskProfiles() async throws -> [ScenarioRiskProfile]
  func createGoal(name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String,
                  monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal
  func updateGoal(id: UUID, name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String,
                  monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal
  func deleteGoal(id: UUID) async throws; func saveRiskProfile(holdingID: UUID, assetCategory: String, sector: String?, region: String?,
                                                               benchmarkProxy: String?, manualValue: Double?, duration: Double?, convexity: Double?) async throws -> ScenarioRiskProfile
  func deleteRiskProfile(id: UUID) async throws
  func createRun(_ input: ScenarioRunRequest, snapshotID: UUID) async throws -> ScenarioRunSummary
  func run(id: UUID) async throws -> ScenarioRunSummary; func cancel(runID: UUID) async throws
}

final class ScenarioPlanningService: ScenarioPlanningServiceProtocol, @unchecked Sendable {
  private let environment: AppEnvironmentManager; private let auth: AuthSessionManaging; private let session: URLSession
  init(environment: AppEnvironmentManager, auth: AuthSessionManaging, session: URLSession = .shared) { self.environment = environment; self.auth = auth; self.session = session }
  func catalog() async throws -> ScenarioCatalogPayload { try await send("v1/scenarios/catalog") }
  func runs() async throws -> [ScenarioRunSummary] { try await send("v1/scenario-runs") }
  func portfolios() async throws -> [ScenarioPortfolio] { try await send("v1/portfolio-lists") }
  func goals() async throws -> [ScenarioGoal] { try await send("v1/financial-goals") }
  func holdings(portfolioIDs: [UUID]) async throws -> [ScenarioHolding] {
    var output: [ScenarioHolding] = []
    for id in portfolioIDs { output += try await send("v1/stocks?portfolioListId=\(id.uuidString)") }
    return output
  }
  func riskProfiles() async throws -> [ScenarioRiskProfile] { try await send("v1/holding-risk-profiles") }
  func createGoal(name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String,
                  monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal {
    try await saveGoal(path: "v1/financial-goals", method: "POST", name: name, portfolioID: portfolioID, targetAmount: targetAmount,
                       targetDate: targetDate, currency: currency, monthlyContribution: monthlyContribution, contributionGrowth: contributionGrowth, inflation: inflation)
  }
  func updateGoal(id: UUID, name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String,
                  monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal {
    try await saveGoal(path: "v1/financial-goals/\(id)", method: "PUT", name: name, portfolioID: portfolioID, targetAmount: targetAmount,
                       targetDate: targetDate, currency: currency, monthlyContribution: monthlyContribution, contributionGrowth: contributionGrowth, inflation: inflation)
  }
  private func saveGoal(path: String, method: String, name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date,
                        currency: String, monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal {
    try await send(path, method: method, body: [
      "name": name, "portfolioListId": portfolioID.uuidString, "targetAmount": targetAmount,
      "targetDate": ISO8601DateFormatter().string(from: targetDate), "baseCurrency": currency.uppercased(),
      "monthlyContribution": monthlyContribution, "annualContributionGrowth": contributionGrowth, "inflationAssumption": inflation,
    ])
  }
  func deleteGoal(id: UUID) async throws { let _: EmptyResponse = try await send("v1/financial-goals/\(id)", method: "DELETE") }
  func saveRiskProfile(holdingID: UUID, assetCategory: String, sector: String?, region: String?, benchmarkProxy: String?,
                       manualValue: Double?, duration: Double?, convexity: Double?) async throws -> ScenarioRiskProfile {
    var body: [String: Any] = ["holdingId": holdingID.uuidString, "assetCategory": assetCategory]
    if let sector { body["sector"] = sector }; if let region { body["region"] = region }
    if let benchmarkProxy { body["benchmarkProxy"] = benchmarkProxy.uppercased() }
    if let manualValue { body["manualValue"] = manualValue }; if let duration { body["duration"] = duration }; if let convexity { body["convexity"] = convexity }
    return try await send("v1/holding-risk-profiles", method: "POST", body: body)
  }
  func deleteRiskProfile(id: UUID) async throws { let _: EmptyResponse = try await send("v1/holding-risk-profiles/\(id)", method: "DELETE") }
  func run(id: UUID) async throws -> ScenarioRunSummary { try await send("v1/scenario-runs/\(id)") }
  func cancel(runID: UUID) async throws { let _: EmptyResponse = try await send("v1/scenario-runs/\(runID)", method: "DELETE") }

  func captureSnapshot(portfolioID: UUID) async throws -> ScenarioSnapshotPreview {
    try await send("v1/portfolio/scenario-snapshots", method: "POST", body: ["portfolioListId": portfolioID.uuidString, "baseCurrency": "USD"])
  }

  func createRun(_ input: ScenarioRunRequest, snapshotID: UUID) async throws -> ScenarioRunSummary {
    let configuration: [String: Any]
    switch input.kind {
    case .historical: configuration = ["catalogId": input.catalogID]
    case .custom: configuration = ["asset_class_shocks": [["target": "stock", "percentage": input.shock]], "horizon_months": min(input.horizonMonths, 120), "recovery": "linear"]
    case .monteCarlo:
      var values: [String: Any] = ["path_count": min(input.pathCount, 50_000), "horizon_months": min(input.horizonMonths, 600), "distribution": input.distribution]
      if !input.assetWeights.isEmpty { values["asset_weights"] = input.assetWeights; values["asset_annual_returns"] = input.assetAnnualReturns; values["annual_covariance"] = input.annualCovariance }
      configuration = values
    }
    var body: [String: Any] = ["name": input.name, "portfolioListId": input.portfolioID.uuidString, "kind": input.kind.rawValue, "configuration": configuration, "isSaved": input.save]
    if let goalID = input.goalID { body["financialGoalId"] = goalID.uuidString }
    let scenario: ScenarioResource = try await send("v1/scenarios", method: "POST", body: body)
    var runBody: [String: Any] = ["snapshotId": snapshotID.uuidString]; if let seed = input.seed { runBody["seed"] = seed }
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
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Response.self, from: data)
  }
}
