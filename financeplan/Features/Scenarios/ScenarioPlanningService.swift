import Foundation

struct ScenarioCatalogPayload: Decodable, Sendable {
  struct Item: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let startDate: String
    let endDate: String
  }
  let version: String
  let historicalScenarios: [Item]
}

struct ScenarioRunSummary: Decodable, Identifiable, Sendable {
  let id: UUID
  let state: String
  let progress: Double
  let engineVersion: String
  let errorMessage: String?
}

protocol ScenarioPlanningServiceProtocol: Sendable {
  func catalog() async throws -> ScenarioCatalogPayload
  func runs() async throws -> [ScenarioRunSummary]
  func cancel(runID: UUID) async throws
}

final class ScenarioPlanningService: ScenarioPlanningServiceProtocol, @unchecked Sendable {
  private let environment: AppEnvironmentManager
  private let auth: AuthSessionManaging
  private let session: URLSession

  init(environment: AppEnvironmentManager, auth: AuthSessionManaging, session: URLSession = .shared) {
    self.environment = environment
    self.auth = auth
    self.session = session
  }

  func catalog() async throws -> ScenarioCatalogPayload { try await get("v1/scenarios/catalog") }
  func runs() async throws -> [ScenarioRunSummary] { try await get("v1/scenario-runs") }

  func cancel(runID: UUID) async throws {
    _ = try await send(path: "v1/scenario-runs/\(runID)", method: "DELETE") as EmptyResponse
  }

  private func get<Response: Decodable>(_ path: String) async throws -> Response {
    try await send(path: path, method: "GET")
  }

  private func send<Response: Decodable>(path: String, method: String) async throws -> Response {
    guard let token = try await auth.validAccessToken() else { throw AuthSessionError.notAuthenticated }
    var request = URLRequest(url: environment.current.apiBaseUrl.appending(path: path))
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    if Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}

private struct EmptyResponse: Decodable {}
