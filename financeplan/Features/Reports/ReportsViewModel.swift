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
  private let stockService: any StockServicing
  private var hasLoadedOnce = false

  private let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      return formatter
  }()

  init(
    expensesService: any ExpensesServicing = Container.shared.expensesService(),
    stockService: any StockServicing = Container.shared.stockService()
  ) {
    self.expensesService = expensesService
    self.stockService = stockService
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

      let portfolioStats = try await resolvePortfolioStatistics(from: report)
      self.portfolioStatistics = portfolioStats
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

  private func resolvePortfolioStatistics(from report: ReportsOverviewResponse) async throws -> ImportedStocksStatisticsDTO {
    let overviewStats = report.portfolioStatistics
    if overviewStats.totalPositions > 0 || overviewStats.totalMarketValue > 0 {
      return overviewStats
    }

    let portfolio = try await stockService.fetchPortfolio()
    guard !portfolio.isEmpty else {
      return overviewStats
    }

    let totalMarketValue = portfolio.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
    let stockAllocations = portfolio.map { stock in
      let value = stock.shares * stock.buyPrice
      let weight = totalMarketValue > 0 ? (value / totalMarketValue) * 100 : 0
      return StockAllocationDTO(symbol: stock.symbol, value: value, weightPercent: weight)
    }

    let stockSummaries = portfolio.map { stock in
      let value = stock.shares * stock.buyPrice
      let weight = totalMarketValue > 0 ? (value / totalMarketValue) * 100 : 0
      return StockStatisticsSummaryDTO(
        symbol: stock.symbol,
        marketValue: value,
        weightPercent: weight,
        unrealizedPnl: 0
      )
    }

    return ImportedStocksStatisticsDTO(
      totalPositions: portfolio.count,
      totalMarketValue: totalMarketValue,
      totalCostBasis: totalMarketValue,
      totalUnrealizedPnl: 0,
      totalRealizedPnl: overviewStats.totalRealizedPnl,
      stockSummaries: stockSummaries,
      stockAllocations: stockAllocations,
      sectorAllocations: overviewStats.sectorAllocations,
      calendarPerformance: overviewStats.calendarPerformance
    )
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
