import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class AdvancedReportingViewModel {
  private(set) var portfolios: [Portfolio] = []
  private(set) var templates: [ReportTemplate] = []
  private(set) var schedules: [ReportSchedule] = []
  private(set) var runs: [ReportRun] = []
  private(set) var isLoading = false
  private(set) var isSaving = false
  var errorMessage: String?

  private let service: any PortfolioReportingServicing

  init(service: any PortfolioReportingServicing = Container.shared.portfolioReportingService()) {
    self.service = service
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let portfolios = service.portfolios()
      async let templates = service.reportTemplates()
      async let schedules = service.reportSchedules()
      async let runs = service.reportRuns()
      (self.portfolios, self.templates, self.schedules, self.runs) = try await (
        portfolios, templates, schedules, runs
      )
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func createTemplate(
    name: String,
    theme: ReportTheme,
    portfolioIds: [String],
    blockKinds: [ReportBlockKind]
  ) async -> Bool {
    await save {
      let blocks = blockKinds.enumerated().map { index, kind in
        ReportBlock(
          id: UUID().uuidString,
          kind: kind,
          title: Self.title(for: kind),
          portfolioIds: portfolioIds,
          dateRange: ReportDateRange(preset: .yearToDate),
          pageBreakBefore: index > 0 && kind == .holdings
        )
      }
      let created = try await service.createReportTemplate(
        ReportTemplateInput(name: name, theme: theme, blocks: blocks)
      )
      templates.insert(created, at: 0)
    }
  }

  func createSchedule(template: ReportTemplate, frequency: ReportRecurrenceFrequency) async -> Bool {
    await save {
      let recurrence = ReportRecurrence(
        frequency: frequency,
        timeZone: TimeZone.current.identifier,
        localTime: "08:00",
        weekday: frequency == .weekly ? .monday : nil,
        dayOfMonth: frequency == .weekly ? nil : 1,
        anchorMonth: frequency == .yearly ? 1 : nil
      )
      let schedule = try await service.createReportSchedule(
        ReportScheduleInput(
          name: "\(template.input.name) delivery",
          templateId: template.id,
          outputFormats: [.pdf, .xlsx],
          recurrence: recurrence,
          recipientUserIds: []
        )
      )
      schedules.insert(schedule, at: 0)
    }
  }

  func generate(template: ReportTemplate, formats: [ReportOutputFormat]) async -> Bool {
    await save {
      let run = try await service.createReportRun(
        ReportRunCreateRequest(templateId: template.id, outputFormats: formats)
      )
      runs.insert(run, at: 0)
    }
  }

  func downloadURL(artifact: ReportArtifact) async -> URL? {
    do {
      let response = try await service.artifactLink(id: artifact.id)
      guard let url = URL(string: response.url) else {
        errorMessage = "The server returned an invalid download link."
        return nil
      }
      return url
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  private func save(_ operation: () async throws -> Void) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await operation()
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  private static func title(for kind: ReportBlockKind) -> String {
    switch kind {
    case .cover: "Portfolio report"
    case .keyMetrics: "Key metrics"
    case .holdings: "Holdings"
    case .allocation: "Allocation"
    case .performance: "Performance"
    case .cashFlow: "Cash flow"
    case .spending: "Spending"
    case .budget: "Budget"
    case .insights: "Insights"
    case .retirementForecast: "Retirement forecast"
    case .hypotheticalComparison: "What-if comparison"
    case .assumptions: "Assumptions"
    case .customText: "Notes"
    case .pageBreak: "Page break"
    }
  }
}
