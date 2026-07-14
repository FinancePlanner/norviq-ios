import Foundation
import StockPlanShared
import Testing
@testable import financeplan

@Suite("Portfolio and reporting workspaces") @MainActor
struct PortfolioReportingViewModelTests {
  @Test("Portfolio workspace loads shared contract models")
  func portfolioWorkspaceLoads() async {
    let service = PortfolioReportingServiceMock()
    service.portfolioItems = [makePortfolio(id: "personal", name: "Personal")]
    let model = PortfolioWorkspaceViewModel(service: service)

    await model.load()

    #expect(model.portfolios.map(\.name) == ["Personal"])
    #expect(model.errorMessage == nil)
    #expect(service.portfolioCalls == 1)
  }

  @Test("What-if clone is appended as hypothetical")
  func clonePortfolio() async {
    let service = PortfolioReportingServiceMock()
    let source = makePortfolio(id: "personal", name: "Personal")
    service.portfolioItems = [source]
    service.clonedPortfolio = makePortfolio(id: "what-if", name: "Personal — What if", mode: .hypothetical)
    let model = PortfolioWorkspaceViewModel(service: service)
    await model.load()

    let succeeded = await model.clone(source, name: "Personal — What if")

    #expect(succeeded)
    #expect(model.portfolios.last?.mode == .hypothetical)
    #expect(service.cloneRequest?.name == "Personal — What if")
  }

  @Test("Reporting builder emits selected blocks and portfolios")
  func reportTemplateBuilder() async {
    let service = PortfolioReportingServiceMock()
    service.createdTemplate = makeTemplate()
    let model = AdvancedReportingViewModel(service: service)

    let succeeded = await model.createTemplate(
      name: "Quarterly review",
      theme: .advisor,
      portfolioIds: ["personal"],
      blockKinds: [.cover, .holdings]
    )

    #expect(succeeded)
    #expect(service.templateInput?.name == "Quarterly review")
    #expect(service.templateInput?.theme == .advisor)
    #expect(service.templateInput?.blocks.map(\.kind) == [.cover, .holdings])
    #expect(service.templateInput?.blocks.allSatisfy { $0.portfolioIds == ["personal"] } == true)
  }

  private func makePortfolio(
    id: String,
    name: String,
    mode: PortfolioMode = .actual
  ) -> Portfolio {
    Portfolio(
      id: id,
      ownerUserId: "owner",
      name: name,
      purpose: .personal,
      ownership: .individual,
      mode: mode,
      baseCurrency: "USD",
      isDefault: mode == .actual,
      currentUserRole: .owner,
      capabilities: PortfolioCapabilities(
        canView: true,
        canEdit: true,
        canManageMembers: true,
        canManageConnections: true,
        canArchive: mode == .hypothetical,
        canDelete: mode == .hypothetical
      ),
      createdAt: "2026-07-14T00:00:00Z"
    )
  }

  private func makeTemplate() -> ReportTemplate {
    ReportTemplate(
      id: "template",
      ownerUserId: "owner",
      input: ReportTemplateInput(
        name: "Quarterly review",
        blocks: [ReportBlock(id: "cover", kind: .cover, title: "Portfolio report")]
      ),
      revision: 1,
      createdAt: "2026-07-14T00:00:00Z"
    )
  }
}

@MainActor
private final class PortfolioReportingServiceMock: PortfolioReportingServicing, @unchecked Sendable {
  var portfolioItems: [Portfolio] = []
  var clonedPortfolio: Portfolio?
  var createdTemplate: ReportTemplate?
  var portfolioCalls = 0
  var cloneRequest: PortfolioCloneRequest?
  var templateInput: ReportTemplateInput?

  func portfolios() async throws -> [Portfolio] {
    portfolioCalls += 1
    return portfolioItems
  }

  func createPortfolio(_: PortfolioCreateRequest) async throws -> Portfolio {
    throw StubError.notConfigured
  }

  func archivePortfolio(id _: String) async throws -> Portfolio {
    throw StubError.notConfigured
  }

  func clonePortfolio(id _: String, request: PortfolioCloneRequest) async throws -> Portfolio {
    cloneRequest = request
    return try #require(clonedPortfolio)
  }

  func comparePortfolios(leftId _: String, rightId _: String) async throws -> PortfolioComparison {
    throw StubError.notConfigured
  }

  func members(portfolioId _: String) async throws -> [PortfolioMembership] {
    []
  }

  func invitations(portfolioId _: String) async throws -> [PortfolioInvitation] {
    []
  }

  func invite(portfolioId _: String, request _: PortfolioInvitationCreateRequest) async throws -> PortfolioInvitation {
    throw StubError.notConfigured
  }

  func cash(portfolioId _: String) async throws -> [PortfolioCashPosition] {
    []
  }

  func addCash(portfolioId _: String, request _: PortfolioCashPositionRequest) async throws -> PortfolioCashPosition {
    throw StubError.notConfigured
  }

  func retirementPlan(portfolioId _: String) async throws -> RetirementPlan {
    throw StubError.notConfigured
  }

  func saveRetirementPlan(portfolioId _: String, request _: RetirementPlanUpsertRequest) async throws -> RetirementPlan {
    throw StubError.notConfigured
  }

  func refreshRetirementRules(portfolioId _: String) async throws -> RetirementPlan {
    throw StubError.notConfigured
  }

  func retirementRules(jurisdiction _: TaxJurisdiction) async throws -> RetirementRulePack {
    throw StubError.notConfigured
  }

  func projectRetirement(portfolioId _: String, request _: RetirementProjectionRequest) async throws -> RetirementProjection {
    throw StubError.notConfigured
  }

  func reportTemplates() async throws -> [ReportTemplate] {
    []
  }

  func createReportTemplate(_ input: ReportTemplateInput) async throws -> ReportTemplate {
    templateInput = input
    return try #require(createdTemplate)
  }

  func reportSchedules() async throws -> [ReportSchedule] {
    []
  }

  func createReportSchedule(_: ReportScheduleInput) async throws -> ReportSchedule {
    throw StubError.notConfigured
  }

  func reportRuns() async throws -> [ReportRun] {
    []
  }

  func createReportRun(_: ReportRunCreateRequest) async throws -> ReportRun {
    throw StubError.notConfigured
  }

  func artifactLink(id _: String) async throws -> ReportArtifactDownloadResponse {
    throw StubError.notConfigured
  }
}

private enum StubError: Error {
  case notConfigured
}
