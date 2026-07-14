import AnyAPI
import Foundation
import StockPlanShared

nonisolated private protocol PortfolioReportingEndpoint: Endpoint {}

extension PortfolioReportingEndpoint {
  nonisolated var decoder: JSONDecoder {
    .stockPlanShared
  }

  nonisolated func asParameters() throws -> Parameters {
    [:]
  }
}

nonisolated private protocol PortfolioReportingBodyEndpoint: PortfolioReportingEndpoint, StockRequestBodyEndpoint {
  associatedtype Payload: Encodable
  var payload: Payload { get }
}

extension PortfolioReportingBodyEndpoint {
  nonisolated func bodyData() throws -> Data? {
    try JSONEncoder.stockPlanShared.encode(payload)
  }
}

nonisolated struct ListPortfoliosEndpoint: PortfolioReportingEndpoint {
  typealias Response = PortfolioPageResponse
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios"
  }
}

nonisolated struct CreatePortfolioEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = Portfolio
  let payload: PortfolioCreateRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios"
  }
}

nonisolated struct ArchivePortfolioEndpoint: PortfolioReportingEndpoint {
  typealias Response = Portfolio
  let portfolioId: String
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/archive"
  }
}

nonisolated struct ClonePortfolioEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = Portfolio
  let portfolioId: String
  let payload: PortfolioCloneRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/clone"
  }
}

nonisolated struct ComparePortfoliosEndpoint: PortfolioReportingEndpoint {
  typealias Response = PortfolioComparison
  let leftId: String
  let rightId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/compare"
  }

  func asParameters() throws -> Parameters {
    ["left": leftId, "right": rightId]
  }
}

nonisolated struct ListPortfolioMembersEndpoint: PortfolioReportingEndpoint {
  typealias Response = [PortfolioMembership]
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/members"
  }
}

nonisolated struct ListPortfolioInvitationsEndpoint: PortfolioReportingEndpoint {
  typealias Response = [PortfolioInvitation]
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/invitations"
  }
}

nonisolated struct InvitePortfolioMemberEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = PortfolioInvitation
  let portfolioId: String
  let payload: PortfolioInvitationCreateRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/invitations"
  }
}

nonisolated struct ListPortfolioCashEndpoint: PortfolioReportingEndpoint {
  typealias Response = [PortfolioCashPosition]
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/cash"
  }
}

nonisolated struct CreatePortfolioCashEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = PortfolioCashPosition
  let portfolioId: String
  let payload: PortfolioCashPositionRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/cash"
  }
}

nonisolated struct GetRetirementPlanEndpoint: PortfolioReportingEndpoint {
  typealias Response = RetirementPlan
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/retirement"
  }
}

nonisolated struct SaveRetirementPlanEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = RetirementPlan
  let portfolioId: String
  let payload: RetirementPlanUpsertRequest
  var method: HTTPMethod {
    .put
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/retirement"
  }
}

nonisolated struct RefreshRetirementRulesEndpoint: PortfolioReportingEndpoint {
  typealias Response = RetirementPlan
  let portfolioId: String
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/retirement/refresh-rules"
  }
}

nonisolated struct ProjectRetirementEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = RetirementProjection
  let portfolioId: String
  let payload: RetirementProjectionRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/retirement/projection"
  }
}

nonisolated struct GetRetirementRulesEndpoint: PortfolioReportingEndpoint {
  typealias Response = RetirementRulePack
  let jurisdiction: TaxJurisdiction
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/retirement/rules/\(jurisdiction.rawValue)"
  }
}

nonisolated struct ListReportTemplatesEndpoint: PortfolioReportingEndpoint {
  typealias Response = ReportTemplatePageResponse
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/reporting/templates"
  }
}

nonisolated struct CreateReportTemplateEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = ReportTemplate
  let payload: ReportTemplateInput
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/reporting/templates"
  }
}

nonisolated struct ListReportSchedulesEndpoint: PortfolioReportingEndpoint {
  typealias Response = ReportSchedulePageResponse
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/reporting/schedules"
  }
}

nonisolated struct CreateReportScheduleEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = ReportSchedule
  let payload: ReportScheduleInput
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/reporting/schedules"
  }
}

nonisolated struct ListReportRunsEndpoint: PortfolioReportingEndpoint {
  typealias Response = ReportRunPageResponse
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/reporting/runs"
  }
}

nonisolated struct CreateReportRunEndpoint: PortfolioReportingBodyEndpoint {
  typealias Response = ReportRun
  let payload: ReportRunCreateRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/reporting/runs"
  }
}

nonisolated struct ReportArtifactLinkEndpoint: PortfolioReportingEndpoint {
  typealias Response = ReportArtifactDownloadResponse
  let artifactId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/reporting/artifacts/\(artifactId)/link"
  }
}
