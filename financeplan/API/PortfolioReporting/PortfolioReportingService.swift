import Foundation
import StockPlanShared

protocol PortfolioReportingServicing: Sendable {
  func portfolios() async throws -> [Portfolio]
  func createPortfolio(_ request: PortfolioCreateRequest) async throws -> Portfolio
  func archivePortfolio(id: String) async throws -> Portfolio
  func clonePortfolio(id: String, request: PortfolioCloneRequest) async throws -> Portfolio
  func comparePortfolios(leftId: String, rightId: String) async throws -> PortfolioComparison
  func members(portfolioId: String) async throws -> [PortfolioMembership]
  func invitations(portfolioId: String) async throws -> [PortfolioInvitation]
  func invite(portfolioId: String, request: PortfolioInvitationCreateRequest) async throws -> PortfolioInvitation
  func cash(portfolioId: String) async throws -> [PortfolioCashPosition]
  func addCash(portfolioId: String, request: PortfolioCashPositionRequest) async throws -> PortfolioCashPosition
  func retirementPlan(portfolioId: String) async throws -> RetirementPlan
  func saveRetirementPlan(portfolioId: String, request: RetirementPlanUpsertRequest) async throws -> RetirementPlan
  func refreshRetirementRules(portfolioId: String) async throws -> RetirementPlan
  func retirementRules(jurisdiction: TaxJurisdiction) async throws -> RetirementRulePack
  func projectRetirement(portfolioId: String, request: RetirementProjectionRequest) async throws -> RetirementProjection
  func reportTemplates() async throws -> [ReportTemplate]
  func createReportTemplate(_ input: ReportTemplateInput) async throws -> ReportTemplate
  func reportSchedules() async throws -> [ReportSchedule]
  func createReportSchedule(_ input: ReportScheduleInput) async throws -> ReportSchedule
  func reportRuns() async throws -> [ReportRun]
  func createReportRun(_ request: ReportRunCreateRequest) async throws -> ReportRun
  func artifactLink(id: String) async throws -> ReportArtifactDownloadResponse
}

final class PortfolioReportingService: PortfolioReportingServicing, Sendable {
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

  func portfolios() async throws -> [Portfolio] {
    try await authenticated { try await $0.call(ListPortfoliosEndpoint()).items }
  }

  func createPortfolio(_ request: PortfolioCreateRequest) async throws -> Portfolio {
    try await authenticated { try await $0.call(CreatePortfolioEndpoint(payload: request)) }
  }

  func archivePortfolio(id: String) async throws -> Portfolio {
    try await authenticated { try await $0.call(ArchivePortfolioEndpoint(portfolioId: id)) }
  }

  func clonePortfolio(id: String, request: PortfolioCloneRequest) async throws -> Portfolio {
    try await authenticated { try await $0.call(ClonePortfolioEndpoint(portfolioId: id, payload: request)) }
  }

  func comparePortfolios(leftId: String, rightId: String) async throws -> PortfolioComparison {
    try await authenticated { try await $0.call(ComparePortfoliosEndpoint(leftId: leftId, rightId: rightId)) }
  }

  func members(portfolioId: String) async throws -> [PortfolioMembership] {
    try await authenticated { try await $0.call(ListPortfolioMembersEndpoint(portfolioId: portfolioId)) }
  }

  func invitations(portfolioId: String) async throws -> [PortfolioInvitation] {
    try await authenticated { try await $0.call(ListPortfolioInvitationsEndpoint(portfolioId: portfolioId)) }
  }

  func invite(portfolioId: String, request: PortfolioInvitationCreateRequest) async throws -> PortfolioInvitation {
    try await authenticated { try await $0.call(
      InvitePortfolioMemberEndpoint(portfolioId: portfolioId, payload: request)
    ) }
  }

  func cash(portfolioId: String) async throws -> [PortfolioCashPosition] {
    try await authenticated { try await $0.call(ListPortfolioCashEndpoint(portfolioId: portfolioId)) }
  }

  func addCash(portfolioId: String, request: PortfolioCashPositionRequest) async throws -> PortfolioCashPosition {
    try await authenticated { try await $0.call(CreatePortfolioCashEndpoint(portfolioId: portfolioId, payload: request)) }
  }

  func retirementPlan(portfolioId: String) async throws -> RetirementPlan {
    try await authenticated { try await $0.call(GetRetirementPlanEndpoint(portfolioId: portfolioId)) }
  }

  func saveRetirementPlan(portfolioId: String, request: RetirementPlanUpsertRequest) async throws -> RetirementPlan {
    try await authenticated { try await $0.call(SaveRetirementPlanEndpoint(portfolioId: portfolioId, payload: request)) }
  }

  func refreshRetirementRules(portfolioId: String) async throws -> RetirementPlan {
    try await authenticated { try await $0.call(RefreshRetirementRulesEndpoint(portfolioId: portfolioId)) }
  }

  func retirementRules(jurisdiction: TaxJurisdiction) async throws -> RetirementRulePack {
    try await authenticated { try await $0.call(GetRetirementRulesEndpoint(jurisdiction: jurisdiction)) }
  }

  func projectRetirement(portfolioId: String, request: RetirementProjectionRequest) async throws -> RetirementProjection {
    try await authenticated { try await $0.call(ProjectRetirementEndpoint(portfolioId: portfolioId, payload: request)) }
  }

  func reportTemplates() async throws -> [ReportTemplate] {
    try await authenticated { try await $0.call(ListReportTemplatesEndpoint()).items }
  }

  func createReportTemplate(_ input: ReportTemplateInput) async throws -> ReportTemplate {
    try await authenticated { try await $0.call(CreateReportTemplateEndpoint(payload: input)) }
  }

  func reportSchedules() async throws -> [ReportSchedule] {
    try await authenticated { try await $0.call(ListReportSchedulesEndpoint()).items }
  }

  func createReportSchedule(_ input: ReportScheduleInput) async throws -> ReportSchedule {
    try await authenticated { try await $0.call(CreateReportScheduleEndpoint(payload: input)) }
  }

  func reportRuns() async throws -> [ReportRun] {
    try await authenticated { try await $0.call(ListReportRunsEndpoint()).items }
  }

  func createReportRun(_ request: ReportRunCreateRequest) async throws -> ReportRun {
    try await authenticated { try await $0.call(CreateReportRunEndpoint(payload: request)) }
  }

  func artifactLink(id: String) async throws -> ReportArtifactDownloadResponse {
    try await authenticated { try await $0.call(ReportArtifactLinkEndpoint(artifactId: id)) }
  }

  private func authenticated<T: Sendable>(
    _ operation: (StockHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      return try await operation(client())
    } catch let error as StockHTTPClient.Error where error.isUnauthorized {
      do {
        return try await operation(client(forceRefresh: true))
      } catch let retryError as StockHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func client(forceRefresh: Bool = false) async throws -> StockHTTPClient {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()
    guard let token, !token.isEmpty else { throw AuthSessionError.notAuthenticated }
    return StockHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }
}
