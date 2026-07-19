import Foundation
import StockPlanShared

protocol TaxServiceProtocol: Sendable {
  func dashboard(jurisdiction: TaxJurisdiction, taxYear: Int) async throws -> TaxDashboardResponse
  func profileContext(jurisdiction: TaxJurisdiction, taxYear: Int) async throws -> TaxProfileContextResponse
  func saveProfile(_ request: TaxProfileRequest) async throws -> TaxProfileResponse
  func saveMarketAdmission(instrumentId: String, status: TaxMarketAdmissionStatus) async throws -> TaxInstrumentMarketOption
  func saveFundClassification(instrumentId: String, classification: TaxFundClassification) async throws -> TaxInstrumentMarketOption
  func saveFundAnnualInput(_ request: TaxFundAnnualInputRequest) async throws -> TaxFundAdvanceLumpSumResponse
  func fundAnnualInput(accountId: String, instrumentId: String, calculationYear: Int) async throws -> TaxFundAdvanceLumpSumResponse
  func createScenario(
    _ request: TaxScenarioRequest,
    jurisdiction: TaxJurisdiction,
    taxYear: Int
  ) async throws -> TaxScenarioResponse
  func createActionPlan(_ request: TaxActionPlanRequest) async throws -> TaxActionPlanResponse
  func actionPlans() async throws -> [TaxActionPlanResponse]
  func transitionActionPlan(id: String, request: TaxActionPlanTransitionRequest) async throws -> TaxActionPlanResponse
  func createLocationScenario(
    _ request: TaxLocationScenarioRequest,
    jurisdiction: TaxJurisdiction,
    taxYear: Int
  ) async throws -> TaxLocationScenarioResponse
  func createPlacementPlan(_ request: TaxPlacementPlanRequest) async throws -> TaxActionPlanResponse
  func dismissOpportunity(id: String, jurisdiction: TaxJurisdiction, taxYear: Int) async throws
  func restoreOpportunity(id: String, taxYear: Int) async throws
  func notificationPreferences() async throws -> TaxNotificationPreferences
  func saveNotificationPreferences(_ request: TaxNotificationPreferences) async throws -> TaxNotificationPreferences
  func reports() async throws -> [TaxReportResponse]
  func createReport(_ request: TaxReportRequest) async throws -> TaxReportResponse
  func downloadReport(_ report: TaxReportResponse) async throws -> URL
  func lossCarryforwards(jurisdiction: TaxJurisdiction, taxYear: Int) async throws -> TaxLossCarryforwardLedgerResponse
}

final class TaxService: TaxServiceProtocol, @unchecked Sendable {
  private let environment: AppEnvironmentManager
  private let auth: AuthSessionManaging
  private let session: URLSession

  init(environment: AppEnvironmentManager, auth: AuthSessionManaging, session: URLSession = .shared) {
    self.environment = environment
    self.auth = auth
    self.session = session
  }

  func dashboard(jurisdiction: TaxJurisdiction, taxYear: Int) async throws -> TaxDashboardResponse {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/dashboard"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
      URLQueryItem(name: "taxYear", value: String(taxYear))
    ]
    guard let url = components?.url else { throw URLError(.badURL) }
    return try await send(url: url, method: "GET", body: Data?.none)
  }

  func profileContext(jurisdiction: TaxJurisdiction, taxYear: Int) async throws -> TaxProfileContextResponse {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/profile/context"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
      URLQueryItem(name: "taxYear", value: String(taxYear))
    ]
    guard let url = components?.url else { throw URLError(.badURL) }
    return try await send(url: url, method: "GET", body: Data?.none)
  }

  func saveProfile(_ request: TaxProfileRequest) async throws -> TaxProfileResponse {
    try await send(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/profile"),
      method: "PUT",
      body: JSONEncoder().encode(request)
    )
  }

  func saveMarketAdmission(
    instrumentId: String,
    status: TaxMarketAdmissionStatus
  )
    async throws -> TaxInstrumentMarketOption
  {
    struct Request: Encodable { let status: TaxMarketAdmissionStatus }
    let url = environment.current.apiBaseUrl
      .appending(path: "v1/tax/instruments/\(instrumentId)/market-admission")
    return try await send(
      url: url,
      method: "PUT",
      body: JSONEncoder().encode(Request(status: status)),
      additionalHeaders: status == .unknown ? [:] : ["X-Tax-Evidence-Attested": "true"]
    )
  }

  func saveFundClassification(
    instrumentId: String,
    classification: TaxFundClassification
  )
    async throws -> TaxInstrumentMarketOption
  {
    let url = environment.current.apiBaseUrl
      .appending(path: "v1/tax/instruments/\(instrumentId)/fund-classification")
    return try await send(
      url: url,
      method: "PUT",
      body: JSONEncoder().encode(TaxFundClassificationRequest(classification: classification))
    )
  }

  func saveFundAnnualInput(_ request: TaxFundAnnualInputRequest) async throws -> TaxFundAdvanceLumpSumResponse {
    try await send(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/funds/annual-inputs"),
      method: "PUT",
      body: JSONEncoder().encode(request)
    )
  }

  func fundAnnualInput(
    accountId: String,
    instrumentId: String,
    calculationYear: Int
  )
    async throws -> TaxFundAdvanceLumpSumResponse
  {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/funds/annual-inputs"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "accountId", value: accountId),
      URLQueryItem(name: "instrumentId", value: instrumentId),
      URLQueryItem(name: "calculationYear", value: String(calculationYear))
    ]
    guard let url = components?.url else { throw URLError(.badURL) }
    return try await send(url: url, method: "GET", body: Data?.none)
  }

  func createScenario(
    _ request: TaxScenarioRequest,
    jurisdiction: TaxJurisdiction,
    taxYear: Int
  )
    async throws -> TaxScenarioResponse
  {
    try await send(
      path: "v1/tax/scenarios",
      body: JSONEncoder().encode(request),
      queryItems: [
        URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
        URLQueryItem(name: "taxYear", value: String(taxYear))
      ]
    )
  }

  func createActionPlan(_ request: TaxActionPlanRequest) async throws -> TaxActionPlanResponse {
    try await send(path: "v1/tax/action-plans", body: JSONEncoder().encode(request))
  }

  func actionPlans() async throws -> [TaxActionPlanResponse] {
    try await send(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/action-plans"),
      method: "GET",
      body: nil
    )
  }

  func transitionActionPlan(
    id: String,
    request: TaxActionPlanTransitionRequest
  )
    async throws -> TaxActionPlanResponse
  {
    try await send(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/action-plans/\(id)"),
      method: "PATCH",
      body: JSONEncoder().encode(request)
    )
  }

  func createLocationScenario(
    _ request: TaxLocationScenarioRequest,
    jurisdiction: TaxJurisdiction,
    taxYear: Int
  )
    async throws -> TaxLocationScenarioResponse
  {
    try await send(
      path: "v1/tax/location-scenarios",
      body: JSONEncoder().encode(request),
      queryItems: [
        URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
        URLQueryItem(name: "taxYear", value: String(taxYear))
      ]
    )
  }

  func createPlacementPlan(_ request: TaxPlacementPlanRequest) async throws -> TaxActionPlanResponse {
    try await send(path: "v1/tax/placement-plans", body: JSONEncoder().encode(request))
  }

  func dismissOpportunity(id: String, jurisdiction: TaxJurisdiction, taxYear: Int) async throws {
    try await sendNoContent(
      path: "v1/tax/opportunities/\(id)/dismiss",
      method: "POST",
      queryItems: [
        URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
        URLQueryItem(name: "taxYear", value: String(taxYear))
      ]
    )
  }

  func restoreOpportunity(id: String, taxYear: Int) async throws {
    try await sendNoContent(
      path: "v1/tax/opportunities/\(id)/dismiss",
      method: "DELETE",
      queryItems: [URLQueryItem(name: "taxYear", value: String(taxYear))]
    )
  }

  func notificationPreferences() async throws -> TaxNotificationPreferences {
    try await send(url: environment.current.apiBaseUrl.appending(path: "v1/tax/notifications"), method: "GET", body: nil)
  }

  func saveNotificationPreferences(_ request: TaxNotificationPreferences) async throws -> TaxNotificationPreferences {
    try await send(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/notifications"),
      method: "PUT",
      body: JSONEncoder().encode(request)
    )
  }

  func reports() async throws -> [TaxReportResponse] {
    try await send(url: environment.current.apiBaseUrl.appending(path: "v1/tax/reports"), method: "GET", body: nil)
  }

  func createReport(_ request: TaxReportRequest) async throws -> TaxReportResponse {
    try await send(path: "v1/tax/reports", body: JSONEncoder().encode(request))
  }

  func downloadReport(_ report: TaxReportResponse) async throws -> URL {
    guard report.status == "ready", report.downloadPath != nil else {
      throw URLError(.resourceUnavailable)
    }
    guard let token = try await auth.validAccessToken() else { throw AuthSessionError.notAuthenticated }
    let url = environment.current.apiBaseUrl.appending(path: "v1/tax/reports/\(report.id)/download")
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
    let destination = FileManager.default.temporaryDirectory
      .appending(path: "norviq-tax-\(report.taxYear)-\(report.id).\(report.format.rawValue)")
    try data.write(to: destination, options: .atomic)
    return destination
  }

  func lossCarryforwards(
    jurisdiction: TaxJurisdiction,
    taxYear: Int
  )
    async throws -> TaxLossCarryforwardLedgerResponse
  {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: "v1/tax/loss-carryforwards"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "jurisdiction", value: jurisdiction.rawValue),
      URLQueryItem(name: "taxYear", value: String(taxYear))
    ]
    guard let url = components?.url else { throw URLError(.badURL) }
    return try await send(url: url, method: "GET", body: nil)
  }

  private func send<Response: Decodable>(path: String, body: Data) async throws -> Response {
    try await send(url: environment.current.apiBaseUrl.appending(path: path), method: "POST", body: body)
  }

  private func send<Response: Decodable>(
    path: String,
    body: Data,
    queryItems: [URLQueryItem]
  )
    async throws -> Response
  {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: path),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = queryItems
    guard let url = components?.url else { throw URLError(.badURL) }
    return try await send(url: url, method: "POST", body: body)
  }

  private func sendNoContent(
    path: String,
    method: String,
    queryItems: [URLQueryItem]
  )
    async throws
  {
    var components = URLComponents(
      url: environment.current.apiBaseUrl.appending(path: path),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = queryItems
    guard let url = components?.url else { throw URLError(.badURL) }
    guard let token = try await auth.validAccessToken() else { throw AuthSessionError.notAuthenticated }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
  }

  private func send<Response: Decodable>(
    url: URL,
    method: String,
    body: Data?,
    additionalHeaders: [String: String] = [:]
  )
    async throws -> Response
  {
    guard let token = try await auth.validAccessToken() else { throw AuthSessionError.notAuthenticated }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    for (name, value) in additionalHeaders {
      request.setValue(value, forHTTPHeaderField: name)
    }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}
