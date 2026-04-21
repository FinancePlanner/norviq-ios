import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockDetailsViewModelTests: XCTestCase {
  @MainActor
  private final class StockServiceMock: StockServicing {
    var fetchStockDetailsCalls = 0
    var createValuationCalls = 0
    var updateValuationCalls = 0
    var lastCreateValuationSymbol: String?
    var lastCreateValuationBearLow: Double?
    var lastCreateValuationBearHigh: Double?
    var lastCreateValuationBaseLow: Double?
    var lastCreateValuationBaseHigh: Double?
    var lastCreateValuationBullLow: Double?
    var lastCreateValuationBullHigh: Double?
    var lastCreateValuationRationale: String?
    var lastCreateValuationTargetDate: String?
    var lastUpdateValuationSymbol: String?
    var lastUpdateValuationBearLow: Double?
    var lastUpdateValuationBearHigh: Double?
    var lastUpdateValuationBaseLow: Double?
    var lastUpdateValuationBaseHigh: Double?
    var lastUpdateValuationBullLow: Double?
    var lastUpdateValuationBullHigh: Double?
    var lastUpdateValuationRationale: String?
    var lastUpdateValuationTargetDate: String?
    var sellStockCalls = 0
    var lastSellStockId: String?
    var lastSellRequest: SellStockRequest?

    var createValuationResult: Result<StockValuationRequest, Error> = .failure(MockError.notConfigured)
    var updateValuationResult: Result<StockValuationRequest, Error> = .failure(MockError.notConfigured)
    var fetchStockDetailsResult: Result<StockDetails, Error> = .failure(MockError.notConfigured)
    var fetchStockInsightsResult: Result<StockInsightsResponse, Error> = .failure(MockError.notConfigured)
    var fetchStockHistoryResult: Result<[StockHistory], Error> = .success([])
    var fetchStockNewsResult: Result<[StockNews], Error> = .success([])
    var getValuationResult: Result<StockValuationRequest, Error> = .failure(StockHTTPClient.Error.invalidStatus(404))
    var updateStockResult: Result<StockResponse, Error> = .failure(MockError.notConfigured)
    var sellStockResult: Result<StockResponse, Error> = .failure(MockError.notConfigured)

    func create(stock _: StockRequest) async throws -> StockResponse {
      throw MockError.notConfigured
    }

    func create(stock: StockRequest, portfolioListId _: String?) async throws -> StockResponse {
      try await create(stock: stock)
    }

    func bulkCreate(stocks _: [StockRequest]) async throws -> BulkStockResponse {
      throw MockError.notConfigured
    }

    func fetchPortfolio() async throws -> [StockResponse] {
      throw MockError.notConfigured
    }

    func fetchPortfolio(portfolioListId _: String?) async throws -> [StockResponse] {
      try await fetchPortfolio()
    }

    func fetchPortfolioPerformance(portfolioListId _: String?) async throws -> PortfolioPerformanceResponse {
      throw MockError.notConfigured
    }

    func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse {
      throw MockError.notConfigured
    }

    func fetchPortfolioSummary(portfolioListId _: String?) async throws -> PortfolioSummaryResponse {
      try await fetchPortfolioSummary()
    }

    func fetchStockDetails(stockId _: String) async throws -> StockDetails {
      fetchStockDetailsCalls += 1
      return try fetchStockDetailsResult.get()
    }

    func fetchStockInsights(symbol _: String) async throws -> StockInsightsResponse {
      try fetchStockInsightsResult.get()
    }

    func fetchStockHistory(symbol _: String) async throws -> [StockHistory] {
      try fetchStockHistoryResult.get()
    }

    func fetchStockNews(symbol _: String) async throws -> [StockNews] {
      try fetchStockNewsResult.get()
    }

    func updateStock(_ stock: StockResponse) async throws -> StockResponse {
      switch updateStockResult {
      case let .success(response):
        return response
      case let .failure(error):
        throw error
      }
    }

    func updateStock(_ stock: StockResponse, portfolioListId _: String?) async throws -> StockResponse {
      try await updateStock(stock)
    }

    func delete(id _: String) async throws {}

    func sellStock(id: String, request: SellStockRequest) async throws -> StockResponse {
      sellStockCalls += 1
      lastSellStockId = id
      lastSellRequest = request
      return try sellStockResult.get()
    }

    func fetchWatchlist() async throws -> [WatchlistItemResponse] {
      throw MockError.notConfigured
    }

    func fetchWatchlist(watchlistListId _: String?) async throws -> [WatchlistItemResponse] {
      try await fetchWatchlist()
    }

    func createWatchlistItem(_ request: WatchlistItemRequest) async throws -> WatchlistItemResponse {
      throw MockError.notConfigured
    }

    func createWatchlistItem(
      _ request: WatchlistItemRequest,
      watchlistListId _: String?
    ) async throws -> WatchlistItemResponse {
      try await createWatchlistItem(request)
    }

    func updateWatchlistItem(
      id _: String,
      request _: WatchlistItemUpdateRequest
    ) async throws -> WatchlistItemResponse {
      throw MockError.notConfigured
    }

    func updateWatchlistItem(
      id: String,
      request: WatchlistItemUpdateRequest,
      watchlistListId _: String?
    ) async throws -> WatchlistItemResponse {
      try await updateWatchlistItem(id: id, request: request)
    }

    func deleteWatchlistItem(id _: String) async throws {
      throw MockError.notConfigured
    }

    func getValuation(symbol _: String) async throws -> StockValuationRequest {
      try getValuationResult.get()
    }

    func createValuation(
      symbol: String,
      draft: StockValuationDraft
    ) async throws -> StockValuationRequest {
      try await createValuation(
        symbol: symbol,
        bearLow: draft.bearLow,
        bearHigh: draft.bearHigh,
        baseLow: draft.baseLow,
        baseHigh: draft.baseHigh,
        bullLow: draft.bullLow,
        bullHigh: draft.bullHigh,
        rationale: draft.rationale,
        targetDate: draft.targetDate
      )
    }

    func createValuation(
      symbol: String,
      bearLow: Double,
      bearHigh: Double,
      baseLow: Double,
      baseHigh: Double,
      bullLow: Double,
      bullHigh: Double,
      rationale: String?,
      targetDate: String?
    ) async throws -> StockValuationRequest {
      createValuationCalls += 1
      lastCreateValuationSymbol = symbol
      lastCreateValuationBearLow = bearLow
      lastCreateValuationBearHigh = bearHigh
      lastCreateValuationBaseLow = baseLow
      lastCreateValuationBaseHigh = baseHigh
      lastCreateValuationBullLow = bullLow
      lastCreateValuationBullHigh = bullHigh
      lastCreateValuationRationale = rationale
      lastCreateValuationTargetDate = targetDate
      return try createValuationResult.get()
    }

    func updateValuation(
      symbol: String,
      draft: StockValuationDraft
    ) async throws -> StockValuationRequest {
      try await updateValuation(
        symbol: symbol,
        bearLow: draft.bearLow,
        bearHigh: draft.bearHigh,
        baseLow: draft.baseLow,
        baseHigh: draft.baseHigh,
        bullLow: draft.bullLow,
        bullHigh: draft.bullHigh,
        rationale: draft.rationale,
        targetDate: draft.targetDate
      )
    }

    func updateValuation(
      symbol: String,
      bearLow: Double,
      bearHigh: Double,
      baseLow: Double,
      baseHigh: Double,
      bullLow: Double,
      bullHigh: Double,
      rationale: String?,
      targetDate: String?
    ) async throws -> StockValuationRequest {
      updateValuationCalls += 1
      lastUpdateValuationSymbol = symbol
      lastUpdateValuationBearLow = bearLow
      lastUpdateValuationBearHigh = bearHigh
      lastUpdateValuationBaseLow = baseLow
      lastUpdateValuationBaseHigh = baseHigh
      lastUpdateValuationBullLow = bullLow
      lastUpdateValuationBullHigh = bullHigh
      lastUpdateValuationRationale = rationale
      lastUpdateValuationTargetDate = targetDate
      return try updateValuationResult.get()
    }
  }

  @MainActor
  private final class MarketDataServiceMock: MarketDataServicing {
    var fetchAnalystConsensusCalls = 0
    var lastFetchAnalystConsensusSymbol: String?
    var fetchStockEarningsCalls = 0
    var lastFetchStockEarningsSymbol: String?
    var fetchCompanyProfileResult: Result<CompanyProfileResponse, Error> = .failure(MockError.notConfigured)
    var fetchQuoteResult: Result<QuoteResponse, Error> = .failure(MockError.notConfigured)
    var fetchAnalystConsensusResult: Result<StockAnalystConsensus, Error> = .failure(MockError.notConfigured)
    var fetchBasicFinancialsResult: Result<StockBasicFinancials, Error> = .failure(MockError.notConfigured)
    var fetchAnalysisMetricsResult: Result<StockAnalysisMetrics, Error> = .failure(MockError.notConfigured)
    var fetchBalanceSheetStatementResult: Result<[BalanceSheetStatementResponse], Error> = .success([])
    var fetchCashFlowStatementResult: Result<[CashFlowStatementResponse], Error> = .success([])
    var fetchRatiosResult: Result<[RatiosResponse], Error> = .success([])
    var fetchRatiosTTMResult: Result<[RatiosTTMResponse], Error> = .success([])
    var fetchFinancialGrowthResult: Result<[FinancialGrowthResponse], Error> = .success([])
    var fetchAnalystEstimatesResult: Result<[AnalystEstimatesResponse], Error> = .success([])
    var fetchStockEarningsResult: Result<[EarningsEvent], Error> = .success([])
    var fetchEarningsCalendarResult: Result<[EarningsEvent], Error> = .success([])
    var fetchMarketNewsResult: Result<[StockNews], Error> = .success([])
    var fetchMarketCompareResult: Result<[StockAnalysisMetrics], Error> = .success([])

    func fetchCompanyProfile(symbol _: String) async throws -> CompanyProfileResponse {
      try fetchCompanyProfileResult.get()
    }

    func fetchQuote(symbol _: String) async throws -> QuoteResponse {
      try fetchQuoteResult.get()
    }

    func fetchAnalystConsensus(symbol: String) async throws -> StockAnalystConsensus {
      fetchAnalystConsensusCalls += 1
      lastFetchAnalystConsensusSymbol = symbol
      return try fetchAnalystConsensusResult.get()
    }

    func fetchBasicFinancials(symbol _: String) async throws -> StockBasicFinancials {
      try fetchBasicFinancialsResult.get()
    }

    func fetchAnalysisMetrics(
      symbol _: String,
      wacc _: Double?,
      terminalGrowthRate _: Double?,
      terminalMargin _: Double?,
      fcfMarginAssumption _: Double?
    ) async throws -> StockAnalysisMetrics {
      try fetchAnalysisMetricsResult.get()
    }

    func fetchMarketCompare(symbols _: [String]) async throws -> [StockAnalysisMetrics] {
      try fetchMarketCompareResult.get()
    }

    func fetchBalanceSheetStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [BalanceSheetStatementResponse] {      try fetchBalanceSheetStatementResult.get()
    }

    func fetchCashFlowStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [CashFlowStatementResponse] {
      try fetchCashFlowStatementResult.get()
    }

    func fetchRatios(symbol _: String, limit _: Int?, period _: String?) async throws -> [RatiosResponse] {
      try fetchRatiosResult.get()
    }

    func fetchRatiosTTM(symbol _: String) async throws -> [RatiosTTMResponse] {
      try fetchRatiosTTMResult.get()
    }

    func fetchFinancialGrowth(symbol _: String, limit _: Int?, period _: String?) async throws -> [FinancialGrowthResponse] {
      try fetchFinancialGrowthResult.get()
    }

    func fetchAnalystEstimates(symbol _: String, limit _: Int?, period _: String?) async throws -> [AnalystEstimatesResponse] {
      try fetchAnalystEstimatesResult.get()
    }

    func fetchStockEarnings(symbol: String, limit _: Int) async throws -> [EarningsEvent] {
      fetchStockEarningsCalls += 1
      lastFetchStockEarningsSymbol = symbol
      return try fetchStockEarningsResult.get()
    }

    func fetchEarningsCalendar(from _: String, to _: String) async throws -> [EarningsEvent] {
      try fetchEarningsCalendarResult.get()
    }

    func fetchMarketNews(limit _: Int?) async throws -> [StockNews] {
      try fetchMarketNewsResult.get()
    }

    func fetchFinancialStatements(symbol: String) async throws -> StockFinancialStatements {
      StockFinancialStatements.from(
        symbol: symbol,
        balanceSheets: try fetchBalanceSheetStatementResult.get(),
        cashFlows: try fetchCashFlowStatementResult.get(),
        ratios: try fetchRatiosResult.get(),
        ratiosTTM: try fetchRatiosTTMResult.get(),
        growth: try fetchFinancialGrowthResult.get(),
        estimates: try fetchAnalystEstimatesResult.get()
      )
    }

    func fetchPriceChart(symbol _: String, range _: String) async throws -> financeplan.PriceChartSeries {
      throw MockError.notConfigured
    }

    func fetchPriceChartComparison(symbols _: [String], range _: String) async throws -> financeplan.PriceChartComparisonResponse {
      throw MockError.notConfigured
    }
  }

  private enum MockError: Error {
    case notConfigured
  }

  private func makeDetails(symbol: String = "AAPL") -> StockDetails {
    StockDetails(
      id: "stock-1",
      symbol: symbol,
      shares: 10,
      buyPrice: 123.45,
      buyDate: "2026-03-13",
      notes: nil
    )
  }

  private func makeValuation(symbol: String = "AAPL") -> StockValuationRequest {
    StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: 100, high: 120),
      baseCase: PriceRange(low: 130, high: 150),
      bullCase: PriceRange(low: 160, high: 190),
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )
  }

  private func makeHistory(date: String = "2026-03-26") -> StockHistory {
    StockHistory(
      date: date,
      open: 120,
      high: 128,
      low: 118,
      close: 125,
      volume: 1_250_000
    )
  }

  private func makeNews(
    title: String = "Apple expands services revenue",
    date: String = "2026-03-26"
  ) -> StockNews {
    StockNews(
      title: title,
      url: "https://example.com/apple-services",
      date: date
    )
  }

  private func makeBasicFinancials(symbol: String = "AAPL") -> StockBasicFinancials {
    StockBasicFinancials(
      symbol: symbol,
      metricType: "all",
      currencyCode: "USD",
      peRatio: 29.4,
      netMargin: 0.2124,
      currentRatio: 1.5401,
      beta: 1.2989,
      fiftyTwoWeekHigh: 310.43,
      fiftyTwoWeekLow: 149.22,
      fiftyTwoWeekLowDate: "2019-01-14",
      fiftyTwoWeekPriceReturnDaily: 101.96334,
      tenDayAverageTradingVolume: 32.50147,
      salesPerShareAnnual: [
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 53.1178),
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 55.9645)
      ],
      currentRatioAnnual: [
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 1.1329),
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 1.5401)
      ],
      netMarginAnnual: [
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 0.2241),
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 0.2124)
      ]
    )
  }

  private func makeBalanceSheetStatements(symbol: String = "AAPL") -> [BalanceSheetStatementResponse] {
    [
      BalanceSheetStatementResponse(
        date: "2024-09-28",
        symbol: symbol,
        reportedCurrency: "USD",
        cik: "0000320193",
        filingDate: "2024-11-01",
        acceptedDate: "2024-11-01 06:01:36",
        fiscalYear: "2024",
        period: "FY",
        cashAndCashEquivalents: 29_943_000_000,
        shortTermInvestments: nil,
        cashAndShortTermInvestments: 52_000_000_000,
        netReceivables: 33_410_000_000,
        accountsReceivables: nil,
        otherReceivables: nil,
        inventory: 7_286_000_000,
        prepaids: nil,
        otherCurrentAssets: nil,
        totalCurrentAssets: 152_987_000_000,
        propertyPlantEquipmentNet: 45_680_000_000,
        goodwill: nil,
        intangibleAssets: nil,
        goodwillAndIntangibleAssets: nil,
        longTermInvestments: nil,
        taxAssets: nil,
        otherNonCurrentAssets: nil,
        totalNonCurrentAssets: 199_876_000_000,
        otherAssets: nil,
        totalAssets: 352_863_000_000,
        totalPayables: nil,
        accountPayables: 64_115_000_000,
        otherPayables: nil,
        accruedExpenses: nil,
        shortTermDebt: 12_000_000_000,
        capitalLeaseOblationsCurrent: nil,
        taxPayables: nil,
        deferredRevenue: nil,
        otherCurrentLiabilities: nil,
        totalCurrentLiabilities: 145_308_000_000,
        longTermDebt: 86_000_000_000,
        deferredRevenueNonCurrent: nil,
        deferredTaxLiabilitiesNonCurrent: nil,
        otherNonCurrentLiabilities: nil,
        totalNonCurrentLiabilities: 118_273_000_000,
        otherLiabilities: nil,
        capitalLeaseObligations: nil,
        totalLiabilities: 263_581_000_000,
        treasuryStock: nil,
        preferredStock: nil,
        commonStock: nil,
        retainedEarnings: nil,
        additionalPaidInCapital: nil,
        accumulatedOtherComprehensiveIncomeLoss: nil,
        otherTotalStockholdersEquity: nil,
        totalStockholdersEquity: 89_282_000_000,
        totalEquity: 89_282_000_000,
        minorityInterest: nil,
        totalLiabilitiesAndTotalEquity: 352_863_000_000,
        totalInvestments: nil,
        totalDebt: 98_000_000_000,
        netDebt: 68_057_000_000
      )
    ]
  }

  private func makeCashFlowStatements(symbol: String = "AAPL") -> [CashFlowStatementResponse] {
    [
      CashFlowStatementResponse(
        date: "2024-09-28",
        symbol: symbol,
        reportedCurrency: "USD",
        cik: "0000320193",
        filingDate: "2024-11-01",
        acceptedDate: "2024-11-01 06:01:36",
        fiscalYear: "2024",
        period: "FY",
        netIncome: 93_736_000_000,
        depreciationAndAmortization: 11_445_000_000,
        deferredIncomeTax: 0,
        stockBasedCompensation: 11_688_000_000,
        changeInWorkingCapital: 3_651_000_000,
        accountsReceivables: -5_144_000_000,
        inventory: -1_046_000_000,
        accountsPayables: 6_020_000_000,
        otherWorkingCapital: 3_821_000_000,
        otherNonCashItems: -2_266_000_000,
        netCashProvidedByOperatingActivities: 118_254_000_000,
        investmentsInPropertyPlantAndEquipment: -9_447_000_000,
        acquisitionsNet: 0,
        purchasesOfInvestments: -48_656_000_000,
        salesMaturitiesOfInvestments: 62_346_000_000,
        otherInvestingActivities: -1_308_000_000,
        netCashProvidedByInvestingActivities: 2_935_000_000,
        netDebtIssuance: -5_998_000_000,
        longTermNetDebtIssuance: -9_958_000_000,
        shortTermNetDebtIssuance: 3_960_000_000,
        netStockIssuance: -94_949_000_000,
        netCommonStockIssuance: -94_949_000_000,
        commonStockIssuance: 0,
        commonStockRepurchased: -94_949_000_000,
        netPreferredStockIssuance: 0,
        netDividendsPaid: -15_234_000_000,
        commonDividendsPaid: -15_234_000_000,
        preferredDividendsPaid: 0,
        otherFinancingActivities: -5_802_000_000,
        netCashProvidedByFinancingActivities: -121_983_000_000,
        effectOfForexChangesOnCash: 0,
        netChangeInCash: -794_000_000,
        cashAtEndOfPeriod: 29_943_000_000,
        cashAtBeginningOfPeriod: 30_737_000_000,
        operatingCashFlow: 118_254_000_000,
        capitalExpenditure: -9_447_000_000,
        freeCashFlow: 108_807_000_000,
        incomeTaxesPaid: 26_102_000_000,
        interestPaid: 0
      )
    ]
  }

  private func makeRatios(symbol: String = "AAPL") -> [RatiosResponse] {
    [
      RatiosResponse(
        symbol: symbol,
        date: "2024-09-28",
        fiscalYear: "2024",
        period: "FY",
        reportedCurrency: "USD",
        grossProfitMargin: 0.46,
        ebitMargin: nil,
        ebitdaMargin: nil,
        operatingProfitMargin: 0.31,
        pretaxProfitMargin: nil,
        continuousOperationsProfitMargin: nil,
        netProfitMargin: 0.24,
        bottomLineProfitMargin: nil,
        receivablesTurnover: nil,
        payablesTurnover: nil,
        inventoryTurnover: nil,
        fixedAssetTurnover: nil,
        assetTurnover: nil,
        currentRatio: 1.1,
        quickRatio: 0.9,
        solvencyRatio: nil,
        cashRatio: nil,
        priceToEarningsRatio: 29.1,
        priceToEarningsGrowthRatio: nil,
        forwardPriceToEarningsGrowthRatio: nil,
        priceToBookRatio: 42.7,
        priceToSalesRatio: 7.6,
        priceToFreeCashFlowRatio: nil,
        priceToOperatingCashFlowRatio: nil,
        debtToAssetsRatio: nil,
        debtToEquityRatio: 1.6,
        debtToCapitalRatio: nil,
        longTermDebtToCapitalRatio: nil,
        financialLeverageRatio: nil,
        workingCapitalTurnoverRatio: nil,
        operatingCashFlowRatio: nil,
        operatingCashFlowSalesRatio: nil,
        freeCashFlowOperatingCashFlowRatio: nil,
        debtServiceCoverageRatio: nil,
        interestCoverageRatio: nil,
        shortTermOperatingCashFlowCoverageRatio: nil,
        operatingCashFlowCoverageRatio: nil,
        capitalExpenditureCoverageRatio: nil,
        dividendPaidAndCapexCoverageRatio: nil,
        dividendPayoutRatio: nil,
        dividendYield: 0.0048,
        dividendYieldPercentage: nil,
        revenuePerShare: nil,
        netIncomePerShare: nil,
        interestDebtPerShare: nil,
        cashPerShare: nil,
        bookValuePerShare: nil,
        tangibleBookValuePerShare: nil,
        shareholdersEquityPerShare: nil,
        operatingCashFlowPerShare: nil,
        capexPerShare: nil,
        freeCashFlowPerShare: nil,
        netIncomePerEBT: nil,
        ebtPerEbit: nil,
        priceToFairValue: nil,
        debtToMarketCap: nil,
        effectiveTaxRate: nil,
        enterpriseValueMultiple: nil
      )
    ]
  }

  private func makeRatiosTTM(symbol: String = "AAPL") -> [RatiosTTMResponse] {
    [
      RatiosTTMResponse(
        symbol: symbol,
        grossProfitMarginTTM: 0.46,
        ebitMarginTTM: nil,
        ebitdaMarginTTM: nil,
        operatingProfitMarginTTM: 0.31,
        pretaxProfitMarginTTM: nil,
        continuousOperationsProfitMarginTTM: nil,
        netProfitMarginTTM: 0.24,
        bottomLineProfitMarginTTM: nil,
        receivablesTurnoverTTM: nil,
        payablesTurnoverTTM: nil,
        inventoryTurnoverTTM: nil,
        fixedAssetTurnoverTTM: nil,
        assetTurnoverTTM: nil,
        currentRatioTTM: 1.1,
        quickRatioTTM: 0.9,
        solvencyRatioTTM: nil,
        cashRatioTTM: nil,
        priceToEarningsRatioTTM: 28.4,
        priceToEarningsGrowthRatioTTM: nil,
        forwardPriceToEarningsGrowthRatioTTM: nil,
        priceToBookRatioTTM: 41.8,
        priceToSalesRatioTTM: 7.4,
        priceToFreeCashFlowRatioTTM: nil,
        priceToOperatingCashFlowRatioTTM: nil,
        debtToAssetsRatioTTM: nil,
        debtToEquityRatioTTM: 1.58,
        debtToCapitalRatioTTM: nil,
        longTermDebtToCapitalRatioTTM: nil,
        financialLeverageRatioTTM: nil,
        workingCapitalTurnoverRatioTTM: nil,
        operatingCashFlowRatioTTM: nil,
        operatingCashFlowSalesRatioTTM: nil,
        freeCashFlowOperatingCashFlowRatioTTM: nil,
        debtServiceCoverageRatioTTM: nil,
        interestCoverageRatioTTM: nil,
        shortTermOperatingCashFlowCoverageRatioTTM: nil,
        operatingCashFlowCoverageRatioTTM: nil,
        capitalExpenditureCoverageRatioTTM: nil,
        dividendPaidAndCapexCoverageRatioTTM: nil,
        dividendPayoutRatioTTM: nil,
        dividendYieldTTM: 0.0047,
        enterpriseValueTTM: nil,
        revenuePerShareTTM: nil,
        netIncomePerShareTTM: nil,
        interestDebtPerShareTTM: nil,
        cashPerShareTTM: nil,
        bookValuePerShareTTM: nil,
        tangibleBookValuePerShareTTM: nil,
        shareholdersEquityPerShareTTM: nil,
        operatingCashFlowPerShareTTM: nil,
        capexPerShareTTM: nil,
        freeCashFlowPerShareTTM: nil,
        netIncomePerEBTTTM: nil,
        ebtPerEbitTTM: nil,
        priceToFairValueTTM: nil,
        debtToMarketCapTTM: nil,
        effectiveTaxRateTTM: nil,
        enterpriseValueMultipleTTM: nil
      )
    ]
  }

  private func makeFinancialGrowth(symbol: String = "AAPL") -> [FinancialGrowthResponse] {
    [
      FinancialGrowthResponse(
        symbol: symbol,
        date: "2024-09-28",
        fiscalYear: "2024",
        period: "FY",
        reportedCurrency: "USD",
        revenueGrowth: 0.06,
        grossProfitGrowth: nil,
        ebitgrowth: nil,
        operatingIncomeGrowth: nil,
        netIncomeGrowth: 0.08,
        epsgrowth: 0.1,
        epsdilutedGrowth: nil,
        weightedAverageSharesGrowth: nil,
        weightedAverageSharesDilutedGrowth: nil,
        dividendsPerShareGrowth: nil,
        operatingCashFlowGrowth: 0.05,
        receivablesGrowth: nil,
        inventoryGrowth: nil,
        assetGrowth: nil,
        bookValueperShareGrowth: nil,
        debtGrowth: nil,
        rdexpenseGrowth: nil,
        sgaexpensesGrowth: nil,
        freeCashFlowGrowth: 0.07,
        tenYRevenueGrowthPerShare: nil,
        fiveYRevenueGrowthPerShare: 0.11,
        threeYRevenueGrowthPerShare: nil,
        tenYOperatingCFGrowthPerShare: nil,
        fiveYOperatingCFGrowthPerShare: nil,
        threeYOperatingCFGrowthPerShare: nil,
        tenYNetIncomeGrowthPerShare: nil,
        fiveYNetIncomeGrowthPerShare: 0.12,
        threeYNetIncomeGrowthPerShare: nil,
        tenYShareholdersEquityGrowthPerShare: nil,
        fiveYShareholdersEquityGrowthPerShare: nil,
        threeYShareholdersEquityGrowthPerShare: nil,
        tenYDividendperShareGrowthPerShare: nil,
        fiveYDividendperShareGrowthPerShare: nil,
        threeYDividendperShareGrowthPerShare: nil,
        ebitdaGrowth: nil,
        growthCapitalExpenditure: nil,
        tenYBottomLineNetIncomeGrowthPerShare: nil,
        fiveYBottomLineNetIncomeGrowthPerShare: nil,
        threeYBottomLineNetIncomeGrowthPerShare: nil
      )
    ]
  }

  private func makeAnalystEstimates(symbol: String = "AAPL") -> [AnalystEstimatesResponse] {
    [
      AnalystEstimatesResponse(
        symbol: symbol,
        date: "2025-09-27",
        revenueLow: nil,
        revenueHigh: nil,
        revenueAvg: 420_000_000_000,
        ebitdaLow: nil,
        ebitdaHigh: nil,
        ebitdaAvg: 145_000_000_000,
        ebitLow: nil,
        ebitHigh: nil,
        ebitAvg: 132_000_000_000,
        netIncomeLow: nil,
        netIncomeHigh: nil,
        netIncomeAvg: 101_000_000_000,
        sgaExpenseLow: nil,
        sgaExpenseHigh: nil,
        sgaExpenseAvg: 27_000_000_000,
        epsAvg: 7.85,
        epsHigh: nil,
        epsLow: nil,
        numAnalystsRevenue: 24,
        numAnalystsEps: 26
      ),
      AnalystEstimatesResponse(
        symbol: symbol,
        date: "2026-09-26",
        revenueLow: nil,
        revenueHigh: nil,
        revenueAvg: 441_000_000_000,
        ebitdaLow: nil,
        ebitdaHigh: nil,
        ebitdaAvg: 154_000_000_000,
        ebitLow: nil,
        ebitHigh: nil,
        ebitAvg: 141_000_000_000,
        netIncomeLow: nil,
        netIncomeHigh: nil,
        netIncomeAvg: 108_000_000_000,
        sgaExpenseLow: nil,
        sgaExpenseHigh: nil,
        sgaExpenseAvg: 28_000_000_000,
        epsAvg: 8.32,
        epsHigh: nil,
        epsLow: nil,
        numAnalystsRevenue: 23,
        numAnalystsEps: 25
      ),
      AnalystEstimatesResponse(
        symbol: symbol,
        date: "2027-09-25",
        revenueLow: nil,
        revenueHigh: nil,
        revenueAvg: 463_000_000_000,
        ebitdaLow: nil,
        ebitdaHigh: nil,
        ebitdaAvg: 163_000_000_000,
        ebitLow: nil,
        ebitHigh: nil,
        ebitAvg: 149_000_000_000,
        netIncomeLow: nil,
        netIncomeHigh: nil,
        netIncomeAvg: 115_000_000_000,
        sgaExpenseLow: nil,
        sgaExpenseHigh: nil,
        sgaExpenseAvg: 29_000_000_000,
        epsAvg: 8.84,
        epsHigh: nil,
        epsLow: nil,
        numAnalystsRevenue: 21,
        numAnalystsEps: 24
      )
    ]
  }

  private func makeAnalysisMetrics(symbol: String = "AAPL") -> StockAnalysisMetrics {
    StockAnalysisMetrics(
      symbol: symbol,
      ttmPE: 18.4,
      forwardPE: 16.2,
      twoYearForwardPE: 14.1,
      ttmEPSGrowth: 0.11,
      currentYearExpectedEPSGrowth: 0.13,
      nextYearEPSGrowth: 0.15,
      ttmRevenueGrowth: 0.09,
      currentYearExpectedRevenueGrowth: 0.1,
      nextYearRevenueGrowth: 0.11,
      grossMargin: 0.58,
      netMargin: 0.22,
      ttmPEGRatio: 1.4,
      lastYearEPSGrowth: 0.08,
      ttmVsNTMEPSGrowth: 0.02,
      currentQuarterEPSGrowthVsPreviousYear: 0.07,
      twoYearStackExpectedEPSGrowth: 0.2995,
      lastYearRevenueGrowth: 0.06,
      ttmVsNTMRevenueGrowth: 0.01,
      currentQuarterRevenueGrowthVsPreviousYear: 0.05,
      twoYearStackExpectedRevenueGrowth: 0.221,
      currentPrice: nil,
      marketCap: nil,
      sharesOutstanding: nil,
      baseYear: nil,
      yearlyProjections: nil,
      wacc: nil,
      terminalGrowthRate: nil,
      terminalMargin: nil,
      exitPELow: nil,
      exitPEHigh: nil,
      dcfBasePrice: nil,
      dcfBearPrice: nil,
      dcfBullPrice: nil,
      netDebt: nil
    )
  }

  private func makeAnalystConsensus(symbol: String = "AAPL") -> StockAnalystConsensus {
    StockAnalystConsensus(
      symbol: symbol,
      strongBuy: 1,
      buy: 49,
      hold: 11,
      sell: 0,
      strongSell: 0,
      consensus: "Buy"
    )
  }

  private func makeInsights(
    symbol: String,
    ttmPE: Double = 24.9,
    grossMargin: Double = 0.81,
    peerSymbols: [String] = ["MSFT", "GOOG"]
  ) -> StockInsightsResponse {
    StockInsightsResponse(
      generatedAt: "2026-04-09T09:00:00Z",
      symbol: symbol,
      profile: StockInsightProfileDTO(
        symbol: symbol,
        companyName: "\(symbol) Inc.",
        currentPrice: 612.42,
        marketCap: 2_500_000_000_000,
        sharesOutstanding: 2_500_000_000,
        metrics: [
          "ttmPE": ttmPE,
          "grossMargin": grossMargin
        ],
        dcfBasePrice: 650,
        dcfBearPrice: 540,
        dcfBullPrice: 760
      ),
      peers: peerSymbols.map { peer in
        StockInsightPeerDTO(
          symbol: peer,
          companyName: "\(peer) Corp",
          currentPrice: 100,
          marketCap: 1_000_000_000_000,
          sharesOutstanding: 1_000_000_000
        )
      },
      projectionScenarios: [
        StockInsightProjectionScenarioDTO(
          kind: "base",
          years: [
            StockInsightProjectionYearDTO(year: 2024, revenue: 360_000_000_000, revenueGrowth: 0.05, netIncome: 96_000_000_000, netIncomeGrowth: 0.06, netMargin: 0.267, eps: 4.8, peLowEstimate: 16, peHighEstimate: 24, sharePriceLow: 76.8, sharePriceHigh: 115.2, cagrLow: -0.15, cagrHigh: -0.09),
            StockInsightProjectionYearDTO(year: 2025, revenue: 381_600_000_000, revenueGrowth: 0.06, netIncome: 103_680_000_000, netIncomeGrowth: 0.08, netMargin: 0.272, eps: 5.4, peLowEstimate: 17, peHighEstimate: 25, sharePriceLow: 91.8, sharePriceHigh: 135.0, cagrLow: -0.13, cagrHigh: -0.07),
            StockInsightProjectionYearDTO(year: 2026, revenue: 404_496_000_000, revenueGrowth: 0.06, netIncome: 112_000_000_000, netIncomeGrowth: 0.08, netMargin: 0.277, eps: 6.0, peLowEstimate: 18, peHighEstimate: 26, sharePriceLow: 108.0, sharePriceHigh: 156.0, cagrLow: -0.11, cagrHigh: -0.06),
            StockInsightProjectionYearDTO(year: 2027, revenue: 428_765_760_000, revenueGrowth: 0.06, netIncome: 120_960_000_000, netIncomeGrowth: 0.08, netMargin: 0.282, eps: 6.6, peLowEstimate: 18, peHighEstimate: 27, sharePriceLow: 118.8, sharePriceHigh: 178.2, cagrLow: -0.10, cagrHigh: -0.05),
            StockInsightProjectionYearDTO(year: 2028, revenue: 454_491_705_600, revenueGrowth: 0.06, netIncome: 130_636_800_000, netIncomeGrowth: 0.08, netMargin: 0.287, eps: 7.2, peLowEstimate: 19, peHighEstimate: 28, sharePriceLow: 136.8, sharePriceHigh: 201.6, cagrLow: -0.08, cagrHigh: -0.03)
          ]
        )
      ]
    )
  }

  func testShareSnapshot_BuildsStructuredExportText() {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    viewModel.details = StockDetails(
      id: "stock-1",
      symbol: "AAPL",
      shares: 10,
      buyPrice: 123.45,
      buyDate: "2026-03-13",
      notes: "Watching margins and installed base growth."
    )
    viewModel.valuation = makeValuation(symbol: "AAPL")
    viewModel.history = [makeHistory()]
    viewModel.news = [
      makeNews(),
      makeNews(title: "Analysts review iPhone demand", date: "2026-03-24")
    ]

    let snapshot = viewModel.shareSnapshot
    let expectedPositionLine = "Position: 10 shares @ \(123.45.currency)"
    let expectedCostBasisLine = "Cost basis: \((10.0 * 123.45).currency)"
    let expectedBearLine = "Bear: \(100.0.currency) - \(120.0.currency)"
    let expectedLatestCloseLine = "Latest close: \(125.0.currency)"

    XCTAssertEqual(snapshot?.title, "AAPL stock snapshot")
    XCTAssertTrue(snapshot?.body.contains("position snapshot") == true)
    XCTAssertTrue(snapshot?.body.contains(expectedPositionLine) == true)
    XCTAssertTrue(snapshot?.body.contains(expectedCostBasisLine) == true)
    XCTAssertTrue(snapshot?.body.contains("Valuation") == true)
    XCTAssertTrue(snapshot?.body.contains(expectedBearLine) == true)
    XCTAssertTrue(snapshot?.body.contains(expectedLatestCloseLine) == true)
    XCTAssertTrue(snapshot?.body.contains("Recent news") == true)
    XCTAssertTrue(snapshot?.body.contains("Apple expands services revenue") == true)
  }

  func testShareSnapshot_IsNilWithoutLoadedDetails() {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    XCTAssertNil(viewModel.shareSnapshot)
  }

  func testDeletePosition_ClearsDetails() async {
    let service = StockServiceMock()
    let initial = makeDetails(symbol: "AAPL")
    service.fetchStockDetailsResult = .success(initial)

    let viewModel = StockDetailsViewModel(service: service)
    await viewModel.load(stockId: initial.id)

    let ok = await viewModel.deletePosition()

    XCTAssertTrue(ok)
    XCTAssertNil(viewModel.details)
    XCTAssertTrue(viewModel.history.isEmpty)
    XCTAssertTrue(viewModel.news.isEmpty)
    XCTAssertNil(viewModel.valuation)
    XCTAssertNil(viewModel.marketSnapshot)
    XCTAssertNil(viewModel.basicFinancials)
    XCTAssertNil(viewModel.financialStatements)
  }

  func testSavePosition_UpdatesDetailsFromService() async {
    let service = StockServiceMock()
    let initial = makeDetails(symbol: "AAPL")
    let updated = StockResponse(
      id: initial.id,
      symbol: initial.symbol,
      shares: 25,
      buyPrice: initial.buyPrice,
      buyDate: initial.buyDate,
      notes: initial.notes
    )
    service.fetchStockDetailsResult = .success(initial)
    service.updateStockResult = .success(updated)

    let viewModel = StockDetailsViewModel(service: service)
    await viewModel.load(stockId: initial.id)

    let ok = await viewModel.savePosition(updated)

    XCTAssertTrue(ok)
    XCTAssertEqual(viewModel.details?.shares, 25)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoad_PopulatesMockInsightsAndDefaultPeers() async throws {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "META"))
    service.fetchStockInsightsResult = .success(makeInsights(symbol: "META"))
    service.fetchStockHistoryResult = .success([makeHistory()])
    service.fetchStockNewsResult = .success([makeNews()])
    service.getValuationResult = .success(makeValuation(symbol: "META"))
    marketDataService.fetchCompanyProfileResult = .success(
      CompanyProfileResponse(
        country: "US",
        currency: "USD",
        estimateCurrency: "USD",
        exchange: "NASDAQ",
        finnhubIndustry: "Communication Services",
        ipo: "2012-05-18",
        logo: "https://example.com/meta.png",
        marketCapitalization: 2_500_000,
        name: "Meta Platforms, Inc.",
        phone: "16505434800",
        shareOutstanding: 2_500,
        ticker: "META",
        weburl: "https://investor.fb.com"
      )
    )
    marketDataService.fetchQuoteResult = .success(
      QuoteResponse(
        symbol: "META",
        currency: "USD",
        currentPrice: 612.42,
        change: 7.15,
        percentChange: 1.18,
        high: 615.20,
        low: 606.30,
        open: 608.10,
        previousClose: 605.27,
        timestamp: 1_775_073_600
      )
    )
    marketDataService.fetchAnalystConsensusResult = .success(makeAnalystConsensus(symbol: "META"))
    marketDataService.fetchBasicFinancialsResult = .success(makeBasicFinancials(symbol: "META"))
    marketDataService.fetchAnalysisMetricsResult = .success(makeAnalysisMetrics(symbol: "META"))
    marketDataService.fetchBalanceSheetStatementResult = .success(makeBalanceSheetStatements(symbol: "META"))
    marketDataService.fetchCashFlowStatementResult = .success(makeCashFlowStatements(symbol: "META"))
    marketDataService.fetchRatiosResult = .success(makeRatios(symbol: "META"))
    marketDataService.fetchRatiosTTMResult = .success(makeRatiosTTM(symbol: "META"))
    marketDataService.fetchFinancialGrowthResult = .success(makeFinancialGrowth(symbol: "META"))
    marketDataService.fetchAnalystEstimatesResult = .success(makeAnalystEstimates(symbol: "META"))

    await viewModel.load(stockId: "stock-1")

    XCTAssertEqual(viewModel.companyProfile?.ticker, "META")
    XCTAssertEqual(viewModel.analystConsensus?.symbol, "META")
    XCTAssertNil(viewModel.analystConsensusMessage)
    XCTAssertEqual(viewModel.basicFinancials?.symbol, "META")
    XCTAssertNil(viewModel.analysisMetrics)
    XCTAssertNil(viewModel.analysisMetricsMessage)
    XCTAssertNil(viewModel.financialStatements)
    XCTAssertNil(viewModel.financialStatementsMessage)
    await viewModel.loadSupplementaryDataIfNeeded(for: .analysis)
    await viewModel.loadSupplementaryDataIfNeeded(for: .statements)
    await viewModel.loadSupplementaryDataIfNeeded(for: .earnings)
    XCTAssertEqual(viewModel.analysisMetrics?.symbol, "META")
    XCTAssertEqual(viewModel.financialStatements?.symbol, "META")
    XCTAssertEqual(viewModel.financialStatements?.ratios(for: .fy).first?.symbol, "META")
    XCTAssertEqual(viewModel.financialStatements?.estimates.count, 3)
    XCTAssertEqual(viewModel.stockEarnings.count, 0)
    XCTAssertEqual(marketDataService.fetchStockEarningsCalls, 1)
    XCTAssertEqual(marketDataService.fetchAnalystConsensusCalls, 1)
    XCTAssertEqual(marketDataService.lastFetchAnalystConsensusSymbol, "META")
    XCTAssertEqual(viewModel.primaryComparisonProfile?.symbol, "META")
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.ttmPE], 18.4)
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.grossMargin], 0.58)
    XCTAssertEqual(viewModel.selectedPeerSymbols.count, 2)
    XCTAssertEqual(viewModel.comparisonProfiles.count, 3)
    XCTAssertNotNil(viewModel.projectionScenario(.base))
    XCTAssertEqual(viewModel.projectionScenario(.base)?.years.count, 5)
    XCTAssertEqual(viewModel.projectionScenario(.base)?.years.last?.year, 2028)
    XCTAssertNotNil(viewModel.marketSnapshot)
    let currentPrice = try XCTUnwrap(viewModel.marketSnapshot?.currentPrice)
    XCTAssertEqual(currentPrice, 612.42, accuracy: 0.001)
  }

  func testLoad_WithoutForceSkipsReloadForSameStock() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "AAPL"))

    await viewModel.load(stockId: "stock-1")
    await viewModel.load(stockId: "stock-1")

    XCTAssertEqual(service.fetchStockDetailsCalls, 1)
  }

  func testLoad_WithForceReloadsForSameStock() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "AAPL"))

    await viewModel.load(stockId: "stock-1")
    await viewModel.load(stockId: "stock-1", force: true)

    XCTAssertEqual(service.fetchStockDetailsCalls, 2)
  }

  func testLoad_WhenOneStatementsEndpointReturnsNotFound_PreservesOtherStatementData() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "UBER"))
    marketDataService.fetchBalanceSheetStatementResult = .success(makeBalanceSheetStatements(symbol: "UBER"))
    marketDataService.fetchCashFlowStatementResult = .success(makeCashFlowStatements(symbol: "UBER"))
    marketDataService.fetchRatiosResult = .success(makeRatios(symbol: "UBER"))
    marketDataService.fetchRatiosTTMResult = .success(makeRatiosTTM(symbol: "UBER"))
    marketDataService.fetchFinancialGrowthResult = .success(makeFinancialGrowth(symbol: "UBER"))
    marketDataService.fetchAnalystEstimatesResult = .failure(MarketDataHTTPClient.Error.api("Not found"))

    await viewModel.load(stockId: "stock-1")
    await viewModel.loadSupplementaryDataIfNeeded(for: .statements)

    XCTAssertEqual(viewModel.financialStatements?.symbol, "UBER")
    XCTAssertEqual(viewModel.financialStatements?.balanceSheets(for: .fy).first?.symbol, "UBER")
    XCTAssertTrue(viewModel.financialStatements?.estimates.isEmpty == true)
    XCTAssertNil(viewModel.financialStatementsMessage)
  }

  func testLoad_WhenConsensusTickerIsUnsupported_SetsWarningWithoutFetchingConsensus() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "ZETA"))

    await viewModel.load(stockId: "stock-1")

    XCTAssertNil(viewModel.analystConsensus)
    XCTAssertEqual(marketDataService.fetchAnalystConsensusCalls, 0)
    XCTAssertEqual(
      viewModel.analystConsensusMessage,
      StockAnalystConsensus.unsupportedPlanMessage(for: "ZETA")
    )
  }

  func testLoad_WhenAnalysisTickerIsUnsupported_SetsWarningWithoutApplyingAnalysisMetrics() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "ZETA"))
    service.fetchStockInsightsResult = .success(makeInsights(symbol: "ZETA", ttmPE: 24.4, grossMargin: 0.61))

    await viewModel.load(stockId: "stock-1")
    await viewModel.loadSupplementaryDataIfNeeded(for: .analysis)

    XCTAssertNil(viewModel.analysisMetrics)
    XCTAssertEqual(
      viewModel.analysisMetricsMessage,
      FMPFreeTierCoverage.unsupportedAnalysisMessage(for: "ZETA")
    )
    XCTAssertEqual(viewModel.primaryComparisonProfile?.symbol, "ZETA")
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.ttmPE], 24.4)
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.grossMargin], 0.61)
  }

  func testLoad_WhenAnalysisMetricsFail_KeepsMockPrimaryProfileMetrics() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "META"))
    service.fetchStockInsightsResult = .success(makeInsights(symbol: "META", ttmPE: 24.9, grossMargin: 0.81))
    marketDataService.fetchAnalysisMetricsResult = .failure(MockError.notConfigured)

    await viewModel.load(stockId: "stock-1")
    await viewModel.loadSupplementaryDataIfNeeded(for: .analysis)

    XCTAssertNil(viewModel.analysisMetrics)
    XCTAssertNil(viewModel.analysisMetricsMessage)
    XCTAssertEqual(viewModel.primaryComparisonProfile?.symbol, "META")
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.ttmPE], 24.9)
    XCTAssertEqual(viewModel.primaryComparisonProfile?.metrics[.grossMargin], 0.81)
  }

  func testLoadSupplementaryDataIfNeeded_EarningsLoadsOnlyOncePerSymbol() async {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "AAPL"))

    await viewModel.load(stockId: "stock-1")
    await viewModel.loadSupplementaryDataIfNeeded(for: .earnings)
    await viewModel.loadSupplementaryDataIfNeeded(for: .earnings)

    XCTAssertEqual(marketDataService.fetchStockEarningsCalls, 1)
    XCTAssertEqual(marketDataService.lastFetchStockEarningsSymbol, "AAPL")
  }

  func testMarketSnapshot_WhenChangeFieldsMissing_ComputesChangeAndPercent() throws {
    let snapshot = StockMarketSnapshot(
      symbol: "TEST",
      currency: "USD",
      currentPrice: 261.74,
      high: 263.31,
      low: 260.68,
      open: 261.07,
      previousClose: 259.45,
      timestamp: 1_582_641_000
    )

    XCTAssertEqual(snapshot.resolvedChange, 2.29, accuracy: 0.001)
    let resolvedPercentChange = try XCTUnwrap(snapshot.resolvedPercentChange)
    XCTAssertEqual(resolvedPercentChange, 2.29 / 259.45, accuracy: 0.0001)
    XCTAssertGreaterThan(snapshot.rangeProgress, 0)
    XCTAssertLessThan(snapshot.rangeProgress, 1)
  }

  func testMarketSnapshot_WhenEndpointProvidesPercentagePoints_NormalizesForDisplay() throws {
    let snapshot = StockMarketSnapshot(
      symbol: "ZETA",
      currency: "USD",
      currentPrice: 15.73,
      change: -0.19,
      percentChange: -1.1935,
      high: 16.3,
      low: 15.53,
      open: 16.2,
      previousClose: 15.92,
      timestamp: 1_775_073_600
    )

    XCTAssertEqual(snapshot.resolvedChange, -0.19, accuracy: 0.0001)
    let resolvedPercentChange = try XCTUnwrap(snapshot.resolvedPercentChange)
    XCTAssertEqual(resolvedPercentChange, -0.011935, accuracy: 0.000001)
  }

  func testUpdatePeerSymbol_WhenSelectingExistingPeer_SwapsVisibleColumns() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "META"))
    await viewModel.load(stockId: "stock-1")

    let firstPeer = viewModel.selectedPeerSymbol(at: 0)
    let secondPeer = viewModel.selectedPeerSymbol(at: 1)

    viewModel.updatePeerSymbol(secondPeer, slot: 0)

    XCTAssertEqual(viewModel.selectedPeerSymbol(at: 0), secondPeer)
    XCTAssertEqual(viewModel.selectedPeerSymbol(at: 1), firstPeer)
  }

  func testSaveValuation_WhenNoExistingValuation_CreatesUsingLoadedDetailsSymbol() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "AAPL")

    viewModel.details = makeDetails(symbol: "AAPL")
    service.createValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.createValuationCalls, 1)
    XCTAssertEqual(service.updateValuationCalls, 0)
    XCTAssertEqual(service.lastCreateValuationSymbol, "AAPL")
    XCTAssertEqual(service.lastCreateValuationBearLow, 100)
    XCTAssertEqual(service.lastCreateValuationBearHigh, 120)
    XCTAssertEqual(service.lastCreateValuationBaseLow, 130)
    XCTAssertEqual(service.lastCreateValuationBaseHigh, 150)
    XCTAssertEqual(service.lastCreateValuationBullLow, 160)
    XCTAssertEqual(service.lastCreateValuationBullHigh, 190)
    XCTAssertEqual(service.lastCreateValuationRationale, "Stable margins with steady growth.")
    XCTAssertEqual(service.lastCreateValuationTargetDate, "2026-12-31")
    XCTAssertEqual(viewModel.valuation, expected)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveValuation_WhenExistingValuation_UpdatesUsingLoadedDetailsSymbol() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "MSFT")

    viewModel.details = makeDetails(symbol: "MSFT")
    viewModel.valuation = makeValuation(symbol: "MSFT")
    service.updateValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.createValuationCalls, 0)
    XCTAssertEqual(service.updateValuationCalls, 1)
    XCTAssertEqual(service.lastUpdateValuationSymbol, "MSFT")
    XCTAssertEqual(service.lastUpdateValuationBearLow, 100)
    XCTAssertEqual(service.lastUpdateValuationBearHigh, 120)
    XCTAssertEqual(service.lastUpdateValuationBaseLow, 130)
    XCTAssertEqual(service.lastUpdateValuationBaseHigh, 150)
    XCTAssertEqual(service.lastUpdateValuationBullLow, 160)
    XCTAssertEqual(service.lastUpdateValuationBullHigh, 190)
    XCTAssertEqual(service.lastUpdateValuationRationale, "Stable margins with steady growth.")
    XCTAssertEqual(service.lastUpdateValuationTargetDate, "2026-12-31")
    XCTAssertEqual(viewModel.valuation, expected)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveValuation_WhenDetailsMissing_UsesExistingValuationSymbolFallback() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "NVDA")

    viewModel.valuation = makeValuation(symbol: "NVDA")
    service.updateValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.updateValuationCalls, 1)
    XCTAssertEqual(service.lastUpdateValuationSymbol, "NVDA")
    XCTAssertEqual(service.lastUpdateValuationBearLow, 100)
    XCTAssertEqual(service.lastUpdateValuationBearHigh, 120)
  }

  func testSaveValuation_WhenNoSymbolAvailable_ReturnsErrorWithoutCallingService() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(message, "Unable to resolve the stock symbol for this valuation.")
    XCTAssertEqual(service.createValuationCalls, 0)
    XCTAssertEqual(service.updateValuationCalls, 0)
  }

  func testSaveValuation_WhenCreateFails_SetsErrorMessage() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    viewModel.details = makeDetails(symbol: "AAPL")
    service.createValuationResult = .failure(StockHTTPClient.Error.api("Body symbol must match the route symbol."))

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(message, "Body symbol must match the route symbol.")
    XCTAssertEqual(viewModel.errorMessage, "Body symbol must match the route symbol.")
    XCTAssertFalse(viewModel.isLoading)
  }

  func testSellPositionPartialSaleUpdatesDetailsAndKeepsScreenOpen() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    viewModel.details = makeDetails(symbol: "AAPL")

    let request = SellStockRequest(
      sharesToSell: 2,
      sellPrice: 200,
      sellDate: "2026-04-10"
    )
    service.sellStockResult = .success(
      StockResponse(
        id: "stock-1",
        symbol: "AAPL",
        shares: 8,
        buyPrice: 123.45,
        buyDate: "2026-03-13",
        notes: nil
      )
    )

    let outcome = await viewModel.sellPosition(request)

    XCTAssertEqual(service.sellStockCalls, 1)
    XCTAssertEqual(service.lastSellStockId, "stock-1")
    XCTAssertEqual(service.lastSellRequest, request)
    XCTAssertFalse(outcome.shouldDismiss)
    XCTAssertNil(outcome.errorMessage)
    XCTAssertEqual(viewModel.details?.shares ?? 0, 8, accuracy: 0.001)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSellPositionFullSaleClearsLoadedStateAndDismisses() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    viewModel.details = makeDetails(symbol: "AAPL")

    let request = SellStockRequest(
      sharesToSell: 10,
      sellPrice: 200,
      sellDate: "2026-04-10"
    )
    service.sellStockResult = .success(
      StockResponse(
        id: "stock-1",
        symbol: "AAPL",
        shares: 0,
        buyPrice: 123.45,
        buyDate: "2026-03-13",
        notes: nil
      )
    )

    let outcome = await viewModel.sellPosition(request)

    XCTAssertEqual(service.sellStockCalls, 1)
    XCTAssertTrue(outcome.shouldDismiss)
    XCTAssertNil(outcome.errorMessage)
    XCTAssertNil(viewModel.details)
    XCTAssertTrue(viewModel.history.isEmpty)
    XCTAssertTrue(viewModel.news.isEmpty)
  }

  func testSellPositionFailureReturnsErrorMessage() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    viewModel.details = makeDetails(symbol: "AAPL")
    service.sellStockResult = .failure(StockHTTPClient.Error.api("Cannot sell more shares than currently owned."))

    let outcome = await viewModel.sellPosition(
      SellStockRequest(
        sharesToSell: 100,
        sellPrice: 200,
        sellDate: "2026-04-10"
      )
    )

    XCTAssertEqual(service.sellStockCalls, 1)
    XCTAssertFalse(outcome.shouldDismiss)
    XCTAssertEqual(outcome.errorMessage, "Cannot sell more shares than currently owned.")
    XCTAssertEqual(viewModel.errorMessage, "Cannot sell more shares than currently owned.")
  }
}
