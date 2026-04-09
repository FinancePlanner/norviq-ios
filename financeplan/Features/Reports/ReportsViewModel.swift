import Combine
import Foundation
import Factory
import StockPlanShared

@MainActor
final class ReportsViewModel: ObservableObject {
  @Published var portfolioStatistics: ImportedStocksStatisticsDTO?
  @Published var monthlySummaries: [BudgetMonthSummary] = []
  @Published var yearlySummaries: [BudgetYearSummaryResponse] = []
  @Published var latestMonthSummary: BudgetMonthSummary?
  @Published var latestPillarSummaries: [PillarPlanningSummaryResponse] = []
  @Published var cashFlow: [ReportsCashFlowPointResponse] = []
  @Published var partnerDisplayName: String = "Partner"
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let expensesService: any ExpensesServicing
  private var hasLoadedOnce = false

  private let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      return formatter
  }()

  init(expensesService: any ExpensesServicing = Container.shared.expensesService()) {
    self.expensesService = expensesService
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    do {
      async let partnerTask = expensesService.getHouseholdPartner()
      async let reportTask = expensesService.getReportsOverview(from: nil, to: nil)
      let (partner, report) = try await (partnerTask, reportTask)

      self.portfolioStatistics = report.portfolioStatistics
      self.yearlySummaries = report.yearlySummaries
      self.latestPillarSummaries = report.latestPillarSummaries
      self.cashFlow = report.cashFlow
      self.partnerDisplayName = partner.displayName ?? "Partner"
      self.monthlySummaries = report.monthlySummaries.compactMap(mapMonthSummary).sorted { $0.monthStart > $1.monthStart }
      self.latestMonthSummary = report.latestMonthSummary.flatMap(mapMonthSummary)
      hasLoadedOnce = true
    } catch {
      self.errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  private func mapMonthSummary(_ report: BudgetMonthSummaryResponse) -> BudgetMonthSummary? {
      guard let monthStart = dateFormatter.date(from: report.monthStart) else { return nil }

      var mappedActuals: [BudgetPillar: Double] = [:]
      for (key, value) in report.pillarActuals {
          if let pillar = BudgetPillar(rawValue: key) { mappedActuals[pillar] = value }
      }

      var mappedPlans: [BudgetPillar: Double] = [:]
      for (key, value) in report.pillarPlans {
          if let pillar = BudgetPillar(rawValue: key) { mappedPlans[pillar] = value }
      }

      return BudgetMonthSummary(
          monthStart: monthStart,
          planned: report.planned,
          actual: report.actual,
          salary: report.salary,
          myPlanned: report.myPlanned,
          partnerPlanned: report.partnerPlanned,
          myActual: report.myActual,
          partnerActual: report.partnerActual,
          pillarActuals: mappedActuals,
          pillarPlans: mappedPlans,
          myPillarActuals: mapPillarValues(report.myPillarActuals),
          partnerPillarActuals: mapPillarValues(report.partnerPillarActuals),
          myPillarPlans: mapPillarValues(report.myPillarPlans),
          partnerPillarPlans: mapPillarValues(report.partnerPillarPlans)
      )
  }

  private func mapPillarValues(_ values: [String: Double]) -> [BudgetPillar: Double] {
    var mapped: [BudgetPillar: Double] = [:]
    for (key, value) in values {
      if let pillar = BudgetPillar(rawValue: key) {
        mapped[pillar] = value
      }
    }
    return mapped
  }
}
