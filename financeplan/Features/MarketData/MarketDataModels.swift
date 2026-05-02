import Foundation
import StockPlanShared

enum FMPFreeTierCoverage {
  static let supportedSymbols: Set<String> = [
    "AAPL", "TSLA", "AMZN", "MSFT", "NVDA", "GOOGL", "META", "NFLX", "JPM", "V",
    "BAC", "PYPL", "DIS", "T", "PFE", "COST", "INTC", "KO", "TGT", "NKE",
    "SPY", "BA", "BABA", "XOM", "WMT", "GE", "CSCO", "VZ", "JNJ", "CVX",
    "PLTR", "SQ", "SHOP", "SBUX", "SOFI", "HOOD", "RBLX", "SNAP", "AMD", "UBER",
    "FDX", "ABBV", "ETSY", "MRNA", "LMT", "GM", "F", "LCID", "CCL", "DAL",
    "UAL", "AAL", "TSM", "SONY", "ET", "MRO", "COIN", "RIVN", "RIOT", "CPRX",
    "VWO", "SPYG", "NOK", "ROKU", "VIAC", "ATVI", "BIDU", "DOCU", "ZM", "PINS",
    "TLRY", "WBA", "MGM", "NIO", "C", "GS", "WFC", "ADBE", "PEP", "UNH",
    "CARR", "HCA", "TWTR", "BILI", "SIRI", "FUBO", "RKT"
  ]

  static func isSupportedTicker(_ symbol: String) -> Bool {
    supportedSymbols.contains(symbol.uppercased())
  }

  static var supportedSymbolsDisplay: String {
    supportedSymbols.sorted().joined(separator: ", ")
  }

  static func unsupportedConsensusMessage(for symbol: String) -> String {
    "Analyst consensus is not available for \(symbol.uppercased()) on the current market data coverage. You can still review the parts of this stock profile that are available."
  }

  static func unsupportedAnalysisMessage(for symbol: String) -> String {
    "Advanced analysis is not available for \(symbol.uppercased()) on the current market data coverage. Try one of the supported symbols, or check Data Availability in Settings."
  }

  static func unsupportedStatementsMessage(for symbol: String) -> String {
    "Financial statements, ratios, and estimates are not available for \(symbol.uppercased()) on the current market data coverage. Try one of the supported symbols, or check Data Availability in Settings."
  }
}

struct YearlyProjection: Equatable, Sendable {
  let year: Int
  let revenue: Double
  let revenueGrowth: Double
  let netIncome: Double
  let netIncomeGrowth: Double
  let netMargin: Double
  let eps: Double
  let fcf: Double?
  let fcfMargin: Double?
}

struct StockAnalysisMetrics: Codable, Equatable, Sendable {
  let symbol: String
  let ttmPE: Double?
  let forwardPE: Double?
  let twoYearForwardPE: Double?
  let ttmEPSGrowth: Double?
  let currentYearExpectedEPSGrowth: Double?
  let nextYearEPSGrowth: Double?
  let ttmRevenueGrowth: Double?
  let currentYearExpectedRevenueGrowth: Double?
  let nextYearRevenueGrowth: Double?
  let grossMargin: Double?
  let netMargin: Double?
  let ttmPEGRatio: Double?
  let lastYearEPSGrowth: Double?
  let ttmVsNTMEPSGrowth: Double?
  let currentQuarterEPSGrowthVsPreviousYear: Double?
  let twoYearStackExpectedEPSGrowth: Double?
  let lastYearRevenueGrowth: Double?
  let ttmVsNTMRevenueGrowth: Double?
  let currentQuarterRevenueGrowthVsPreviousYear: Double?
  let twoYearStackExpectedRevenueGrowth: Double?

  // Forecast / DCF metrics
  let currentPrice: Double?
  let marketCap: Double?
  let sharesOutstanding: Double?
  let baseYear: Int?
  let yearlyProjections: [YearlyProjection]?
  let wacc: Double?
  let terminalGrowthRate: Double?
  let terminalMargin: Double?
  let exitPELow: Double?
  let exitPEHigh: Double?
  let dcfBasePrice: Double?
  let dcfBearPrice: Double?
  let dcfBullPrice: Double?
  let netDebt: Double?

  var comparisonMetrics: [StockComparisonMetric: Double] {
    var metrics: [StockComparisonMetric: Double] = [:]

    metrics[.ttmPE] = ttmPE
    metrics[.forwardPE] = forwardPE
    metrics[.twoYearForwardPE] = twoYearForwardPE
    metrics[.ttmEPSGrowth] = ttmEPSGrowth
    metrics[.currentYearExpectedEPSGrowth] = currentYearExpectedEPSGrowth
    metrics[.nextYearEPSGrowth] = nextYearEPSGrowth
    metrics[.ttmRevenueGrowth] = ttmRevenueGrowth
    metrics[.currentYearExpectedRevenueGrowth] = currentYearExpectedRevenueGrowth
    metrics[.nextYearRevenueGrowth] = nextYearRevenueGrowth
    metrics[.grossMargin] = grossMargin
    metrics[.netMargin] = netMargin
    metrics[.ttmPEGRatio] = ttmPEGRatio
    metrics[.lastYearEPSGrowth] = lastYearEPSGrowth
    metrics[.ttmVsNTMEPSGrowth] = ttmVsNTMEPSGrowth
    metrics[.currentQuarterEPSGrowthVsPreviousYear] = currentQuarterEPSGrowthVsPreviousYear
    metrics[.twoYearStackExpectedEPSGrowth] = twoYearStackExpectedEPSGrowth
    metrics[.lastYearRevenueGrowth] = lastYearRevenueGrowth
    metrics[.ttmVsNTMRevenueGrowth] = ttmVsNTMRevenueGrowth
    metrics[.currentQuarterRevenueGrowthVsPreviousYear] = currentQuarterRevenueGrowthVsPreviousYear
    metrics[.twoYearStackExpectedRevenueGrowth] = twoYearStackExpectedRevenueGrowth
    metrics[.dcfFairValue] = dcfBasePrice

    return metrics.compactMapValues { $0 }
  }
}

struct StockAnalystConsensus: Equatable, Sendable {
  let symbol: String
  let strongBuy: Int
  let buy: Int
  let hold: Int
  let sell: Int
  let strongSell: Int
  let consensus: String

  var totalRatings: Int {
    strongBuy + buy + hold + sell + strongSell
  }

  var bullishRatings: Int {
    strongBuy + buy
  }

  var bearishRatings: Int {
    sell + strongSell
  }

  var bullishShare: Double? {
    guard totalRatings > 0 else { return nil }
    return Double(bullishRatings) / Double(totalRatings)
  }

  var buckets: [StockAnalystConsensusBucket] {
    [
      StockAnalystConsensusBucket(kind: .strongBuy, count: strongBuy),
      StockAnalystConsensusBucket(kind: .buy, count: buy),
      StockAnalystConsensusBucket(kind: .hold, count: hold),
      StockAnalystConsensusBucket(kind: .sell, count: sell),
      StockAnalystConsensusBucket(kind: .strongSell, count: strongSell)
    ]
  }
}

struct StockAnalystConsensusBucket: Identifiable, Equatable, Sendable {
  let kind: StockAnalystConsensusBucketKind
  let count: Int

  var id: StockAnalystConsensusBucketKind { kind }
}

enum StockAnalystConsensusBucketKind: String, CaseIterable, Codable, Identifiable, Sendable {
  case strongBuy
  case buy
  case hold
  case sell
  case strongSell

  var id: String { rawValue }

  var title: String {
    switch self {
    case .strongBuy:
      return "Strong buy"
    case .buy:
      return "Buy"
    case .hold:
      return "Hold"
    case .sell:
      return "Sell"
    case .strongSell:
      return "Strong sell"
    }
  }
}

extension StockAnalystConsensus {
  static func isSupportedTicker(_ symbol: String) -> Bool {
    FMPFreeTierCoverage.isSupportedTicker(symbol)
  }

  static func unsupportedPlanMessage(for symbol: String) -> String {
    FMPFreeTierCoverage.unsupportedConsensusMessage(for: symbol)
  }

  static func mock(symbol: String) -> StockAnalystConsensus {
    StockAnalystConsensus(
      symbol: symbol.uppercased(),
      strongBuy: 1,
      buy: 29,
      hold: 11,
      sell: 4,
      strongSell: 0,
      consensus: "Buy"
    )
  }
}

struct StockBasicFinancials: Equatable {
  let symbol: String
  let metricType: String
  let currencyCode: String?
  let peRatio: Double?
  let netMargin: Double?
  let currentRatio: Double?
  let beta: Double?
  let fiftyTwoWeekHigh: Double?
  let fiftyTwoWeekLow: Double?
  let fiftyTwoWeekLowDate: String?
  let fiftyTwoWeekPriceReturnDaily: Double?
  let tenDayAverageTradingVolume: Double?
  let salesPerShareAnnual: [StockBasicFinancialSeriesPoint]
  let currentRatioAnnual: [StockBasicFinancialSeriesPoint]
  let netMarginAnnual: [StockBasicFinancialSeriesPoint]

  var overviewItems: [StockBasicFinancialMetricItem] {
    [
      item(id: "peRatio", title: "P/E ratio", value: peRatio, format: .multiple),
      item(id: "netMargin", title: "Net margin", value: netMargin, format: .percentFraction),
      item(id: "currentRatio", title: "Current ratio", value: currentRatio, format: .plain(decimals: 2)),
      item(id: "beta", title: "Beta", value: beta, format: .plain(decimals: 2)),
      item(id: "52WeekHigh", title: "52W high", value: fiftyTwoWeekHigh, format: .price),
      item(
        id: "52WeekLow",
        title: "52W low",
        value: fiftyTwoWeekLow,
        format: .price,
        detail: formattedMetricDate(from: fiftyTwoWeekLowDate)
      ),
      item(
        id: "52WeekReturn",
        title: "52W return",
        value: fiftyTwoWeekPriceReturnDaily,
        format: .percentPoints
      ),
      item(
        id: "10DayAverageTradingVolume",
        title: "10D avg volume",
        value: tenDayAverageTradingVolume,
        format: .volume
      )
    ]
    .compactMap { $0 }
  }

  var annualSeriesItems: [StockBasicFinancialMetricItem] {
    [
      latestSeriesItem(
        id: "salesPerShare",
        title: "Sales/share",
        points: salesPerShareAnnual,
        format: .plain(decimals: 2)
      ),
      latestSeriesItem(
        id: "currentRatioAnnual",
        title: "Current ratio",
        points: currentRatioAnnual,
        format: .plain(decimals: 2)
      ),
      latestSeriesItem(
        id: "netMarginAnnual",
        title: "Net margin",
        points: netMarginAnnual,
        format: .percentFraction
      )
    ]
    .compactMap { $0 }
  }

  private func item(
    id: String,
    title: String,
    value: Double?,
    format: StockBasicFinancialMetricFormat,
    detail: String? = nil
  ) -> StockBasicFinancialMetricItem? {
    guard let value else { return nil }
    return StockBasicFinancialMetricItem(
      id: id,
      title: title,
      value: value,
      format: format,
      detail: detail
    )
  }

  private func latestSeriesItem(
    id: String,
    title: String,
    points: [StockBasicFinancialSeriesPoint],
    format: StockBasicFinancialMetricFormat
  ) -> StockBasicFinancialMetricItem? {
    guard let point = points.sorted(by: { $0.period > $1.period }).first else { return nil }
    return StockBasicFinancialMetricItem(
      id: id,
      title: title,
      value: point.value,
      format: format,
      detail: formattedMetricDate(from: point.period) ?? point.period
    )
  }
}

struct StockBasicFinancialSeriesPoint: Equatable, Identifiable {
  let period: String
  let value: Double

  var id: String {
    "\(period)-\(value)"
  }
}

struct StockBasicFinancialMetricItem: Equatable, Identifiable {
  let id: String
  let title: String
  let value: Double
  let format: StockBasicFinancialMetricFormat
  let detail: String?
}

enum StockBasicFinancialMetricFormat: Equatable {
  case price
  case multiple
  case percentFraction
  case percentPoints
  case plain(decimals: Int)
  case volume
}

enum StockFinancialStatementPeriod: String, CaseIterable, Identifiable {
  case q1 = "Q1"
  case q2 = "Q2"
  case q3 = "Q3"
  case q4 = "Q4"
  case fy = "FY"
  case annual = "annual"
  case quarter = "quarter"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .annual:
      return "Annual"
    case .quarter:
      return "Quarter"
    case .q1, .q2, .q3, .q4, .fy:
      return rawValue
    }
  }
}

struct StockFinancialStatements: Equatable {
  let symbol: String
  let balanceSheets: [StockFinancialStatement]
  let cashFlows: [StockFinancialStatement]
  let ratios: [StockFinancialMetricSnapshot]
  let growth: [StockFinancialMetricSnapshot]
  let estimates: [StockFinancialMetricSnapshot]

  static func from(
    symbol: String,
    balanceSheets: [BalanceSheetStatementResponse],
    cashFlows: [CashFlowStatementResponse],
    ratios: [RatiosResponse],
    ratiosTTM: [RatiosTTMResponse],
    growth: [FinancialGrowthResponse],
    estimates: [AnalystEstimatesResponse]
  ) -> StockFinancialStatements {
    let ttmSnapshots: [StockFinancialMetricSnapshot] = ratiosTTM.map { res in
      StockFinancialMetricSnapshot(
        date: "TTM",
        symbol: res.symbol,
        fiscalYear: nil,
        period: "TTM",
        reportedCurrency: nil,
        entries: [
          .init(id: "grossProfitMarginTTM", title: "Gross margin", value: res.grossProfitMarginTTM, format: .percentFraction),
          .init(id: "netProfitMarginTTM", title: "Net margin", value: res.netProfitMarginTTM, format: .percentFraction),
          .init(id: "operatingProfitMarginTTM", title: "Operating margin", value: res.operatingProfitMarginTTM, format: .percentFraction),
          .init(id: "returnOnEquityTTM", title: "Return on equity", value: res.debtToEquityRatioTTM, format: .percentFraction),
          .init(id: "currentRatioTTM", title: "Current ratio", value: res.currentRatioTTM, format: .multiple(decimals: 2)),
          .init(id: "quickRatioTTM", title: "Quick ratio", value: res.quickRatioTTM, format: .multiple(decimals: 2)),
          .init(id: "priceToEarningsRatioTTM", title: "P/E ratio", value: res.priceToEarningsRatioTTM, format: .multiple(decimals: 2)),
          .init(id: "priceToBookRatioTTM", title: "P/B ratio", value: res.priceToBookRatioTTM, format: .multiple(decimals: 2)),
          .init(id: "priceToSalesRatioTTM", title: "P/S ratio", value: res.priceToSalesRatioTTM, format: .multiple(decimals: 2)),
          .init(id: "dividendYieldTTM", title: "Dividend yield", value: res.dividendYieldTTM, format: .percentFraction)
        ]
      )
    }

    let historicalRatios: [StockFinancialMetricSnapshot] = ratios.map { res in
      StockFinancialMetricSnapshot(
        date: res.date,
        symbol: res.symbol,
        fiscalYear: res.fiscalYear,
        period: res.period,
        reportedCurrency: res.reportedCurrency,
        entries: [
          .init(id: "grossProfitMargin", title: "Gross margin", value: res.grossProfitMargin, format: .percentFraction),
          .init(id: "netProfitMargin", title: "Net margin", value: res.netProfitMargin, format: .percentFraction),
          .init(id: "operatingProfitMargin", title: "Operating margin", value: res.operatingProfitMargin, format: .percentFraction),
          .init(id: "returnOnEquity", title: "Return on equity", value: res.debtToEquityRatio, format: .percentFraction),
          .init(id: "currentRatio", title: "Current ratio", value: res.currentRatio, format: .multiple(decimals: 2)),
          .init(id: "quickRatio", title: "Quick ratio", value: res.quickRatio, format: .multiple(decimals: 2)),
          .init(id: "priceToEarningsRatio", title: "P/E ratio", value: res.priceToEarningsRatio, format: .multiple(decimals: 2)),
          .init(id: "priceToBookRatio", title: "P/B ratio", value: res.priceToBookRatio, format: .multiple(decimals: 2)),
          .init(id: "priceToSalesRatio", title: "P/S ratio", value: res.priceToSalesRatio, format: .multiple(decimals: 2)),
          .init(id: "dividendYield", title: "Dividend yield", value: res.dividendYield, format: .percentFraction)
        ]
      )
    }

    return StockFinancialStatements(
      symbol: symbol,
      balanceSheets: balanceSheets.map { res in
        StockFinancialStatement(
          date: res.date,
          symbol: res.symbol,
          reportedCurrency: res.reportedCurrency ?? "USD",
          cik: res.cik ?? "",
          filingDate: res.filingDate ?? res.date,
          acceptedDate: res.acceptedDate ?? res.date,
          fiscalYear: res.fiscalYear ?? "",
          period: res.period ?? "FY",
          entries: [
            .init(id: "cashAndCashEquivalents", title: "Cash & equivalents", value: res.cashAndCashEquivalents ?? 0),
            .init(id: "shortTermInvestments", title: "Short-term investments", value: res.shortTermInvestments ?? 0),
            .init(id: "cashAndShortTermInvestments", title: "Cash + short-term investments", value: res.cashAndShortTermInvestments ?? 0),
            .init(id: "netReceivables", title: "Net receivables", value: res.netReceivables ?? 0),
            .init(id: "inventory", title: "Inventory", value: res.inventory ?? 0),
            .init(id: "totalCurrentAssets", title: "Total current assets", value: res.totalCurrentAssets ?? 0),
            .init(id: "propertyPlantEquipmentNet", title: "PP&E, net", value: res.propertyPlantEquipmentNet ?? 0),
            .init(id: "goodwillAndIntangibleAssets", title: "Goodwill & intangibles", value: res.goodwillAndIntangibleAssets ?? 0),
            .init(id: "totalAssets", title: "Total assets", value: res.totalAssets ?? 0),
            .init(id: "accountPayables", title: "Accounts payables", value: res.accountPayables ?? 0),
            .init(id: "totalCurrentLiabilities", title: "Total current liabilities", value: res.totalCurrentLiabilities ?? 0),
            .init(id: "longTermDebt", title: "Long-term debt", value: res.longTermDebt ?? 0),
            .init(id: "totalLiabilities", title: "Total liabilities", value: res.totalLiabilities ?? 0),
            .init(id: "totalStockholdersEquity", title: "Total stockholders equity", value: res.totalStockholdersEquity ?? 0),
            .init(id: "totalEquity", title: "Total equity", value: res.totalEquity ?? 0)
          ]
        )
      },
      cashFlows: cashFlows.map { res in
        StockFinancialStatement(
          date: res.date,
          symbol: res.symbol,
          reportedCurrency: res.reportedCurrency ?? "USD",
          cik: res.cik ?? "",
          filingDate: res.filingDate ?? res.date,
          acceptedDate: res.acceptedDate ?? res.date,
          fiscalYear: res.fiscalYear ?? "",
          period: res.period ?? "FY",
          entries: [
            .init(id: "netIncome", title: "Net income", value: res.netIncome ?? 0),
            .init(id: "depreciationAndAmortization", title: "D&A", value: res.depreciationAndAmortization ?? 0),
            .init(id: "stockBasedCompensation", title: "Stock-based comp", value: res.stockBasedCompensation ?? 0),
            .init(id: "operatingCashFlow", title: "Operating cash flow", value: res.operatingCashFlow ?? 0),
            .init(id: "capitalExpenditure", title: "Capital expenditure", value: res.capitalExpenditure ?? 0),
            .init(id: "freeCashFlow", title: "Free cash flow", value: res.freeCashFlow ?? 0),
            .init(id: "commonStockRepurchased", title: "Common stock repurchased", value: res.commonStockRepurchased ?? 0),
            .init(id: "commonDividendsPaid", title: "Common dividends paid", value: res.commonDividendsPaid ?? 0)
          ]
        )
      },
      ratios: ttmSnapshots + historicalRatios,
      growth: growth.map { res in
        StockFinancialMetricSnapshot(
          date: res.date,
          symbol: res.symbol,
          fiscalYear: res.fiscalYear,
          period: res.period,
          reportedCurrency: res.reportedCurrency,
          entries: [
            .init(id: "revenueGrowth", title: "Revenue growth", value: res.revenueGrowth, format: .percentFraction),
            .init(id: "netIncomeGrowth", title: "Net income growth", value: res.netIncomeGrowth, format: .percentFraction),
            .init(id: "epsgrowth", title: "EPS growth", value: res.epsgrowth, format: .percentFraction),
            .init(id: "operatingCashFlowGrowth", title: "Operating CF growth", value: res.operatingCashFlowGrowth, format: .percentFraction),
            .init(id: "freeCashFlowGrowth", title: "Free CF growth", value: res.freeCashFlowGrowth, format: .percentFraction),
            .init(id: "fiveYRevenueGrowthPerShare", title: "5Y Rev/Share growth", value: res.fiveYRevenueGrowthPerShare, format: .percentFraction),
            .init(id: "fiveYNetIncomeGrowthPerShare", title: "5Y NetInc/Share growth", value: res.fiveYNetIncomeGrowthPerShare, format: .percentFraction)
          ]
        )
      },
      estimates: estimates.map { res in
        StockFinancialMetricSnapshot(
          date: res.date,
          symbol: res.symbol,
          fiscalYear: nil,
          period: nil,
          reportedCurrency: nil,
          entries: [
            .init(id: "revenueAvg", title: "Revenue avg", value: res.revenueAvg, format: .currencyCompact),
            .init(id: "ebitdaAvg", title: "EBITDA avg", value: res.ebitdaAvg, format: .currencyCompact),
            .init(id: "netIncomeAvg", title: "Net income avg", value: res.netIncomeAvg, format: .currencyCompact),
            .init(id: "epsAvg", title: "EPS avg", value: res.epsAvg, format: .currency(decimals: 2)),
            .init(id: "numAnalystsRevenue", title: "Revenue analysts", value: Double(res.numAnalystsRevenue ?? 0), format: .count),
            .init(id: "numAnalystsEps", title: "EPS analysts", value: Double(res.numAnalystsEps ?? 0), format: .count)
          ]
        )
      }
    )
  }

  func balanceSheets(for period: StockFinancialStatementPeriod) -> [StockFinancialStatement] {
    filtered(balanceSheets, for: period)
  }

  func cashFlows(for period: StockFinancialStatementPeriod) -> [StockFinancialStatement] {
    filtered(cashFlows, for: period)
  }

  func ratios(for period: StockFinancialStatementPeriod) -> [StockFinancialMetricSnapshot] {
    filtered(ratios, for: period)
  }

  func growth(for period: StockFinancialStatementPeriod) -> [StockFinancialMetricSnapshot] {
    filtered(growth, for: period)
  }

  private func filtered(
    _ statements: [StockFinancialStatement],
    for period: StockFinancialStatementPeriod
  ) -> [StockFinancialStatement] {
    let sorted = statements.sorted { $0.date > $1.date }

    switch period {
    case .annual:
      return sorted.filter { $0.period.uppercased() == StockFinancialStatementPeriod.fy.rawValue }
    case .quarter:
      return sorted.filter { $0.period.uppercased().hasPrefix("Q") }
    case .fy:
      return sorted.first(where: { $0.period.uppercased() == period.rawValue }).map { [$0] } ?? []
    case .q1, .q2, .q3, .q4:
      return sorted.first(where: { $0.period.uppercased() == period.rawValue }).map { [$0] } ?? []
    }
  }

  private func filtered(
    _ snapshots: [StockFinancialMetricSnapshot],
    for period: StockFinancialStatementPeriod
  ) -> [StockFinancialMetricSnapshot] {
    let sorted = snapshots.sorted { $0.date > $1.date }

    switch period {
    case .annual:
      return sorted.filter { $0.normalizedPeriod == StockFinancialStatementPeriod.fy.rawValue }
    case .quarter:
      return sorted.filter { ($0.normalizedPeriod ?? "").hasPrefix("Q") }
    case .fy:
      return sorted.first(where: { $0.normalizedPeriod == period.rawValue }).map { [$0] } ?? []
    case .q1, .q2, .q3, .q4:
      return sorted.first(where: { $0.normalizedPeriod == period.rawValue }).map { [$0] } ?? []
    }
  }
}

struct StockFinancialStatement: Identifiable, Equatable {
  let date: String
  let symbol: String
  let reportedCurrency: String
  let cik: String
  let filingDate: String
  let acceptedDate: String
  let fiscalYear: String
  let period: String
  let entries: [StockFinancialStatementEntry]

  var id: String {
    "\(symbol)-\(period)-\(date)"
  }

  var displayColumnTitle: String {
    let normalizedPeriod = period.uppercased()
    if normalizedPeriod == StockFinancialStatementPeriod.fy.rawValue {
      return "FY \(fiscalYear)"
    }
    if normalizedPeriod.hasPrefix("Q") {
      return "\(normalizedPeriod) \(fiscalYear)"
    }
    return formattedMetricDate(from: date) ?? date
  }

  var formattedDate: String {
    formattedMetricDate(from: date) ?? date
  }

  var formattedFilingDate: String {
    formattedMetricDate(from: filingDate) ?? filingDate
  }

  func value(for entryID: String) -> Double? {
    entries.first(where: { $0.id == entryID })?.value
  }
}

struct StockFinancialStatementEntry: Identifiable, Equatable {
  let id: String
  let title: String
  let value: Double
}

struct StockFinancialMetricSnapshot: Identifiable, Equatable {
  let date: String
  let symbol: String
  let fiscalYear: String?
  let period: String?
  let reportedCurrency: String?
  let entries: [StockFinancialMetricEntry]

  var id: String {
    let periodComponent = period ?? "none"
    return "\(symbol)-\(periodComponent)-\(date)"
  }

  var normalizedPeriod: String? {
    period?.uppercased()
  }

  var displayColumnTitle: String {
    if let normalizedPeriod, normalizedPeriod == StockFinancialStatementPeriod.fy.rawValue, let fiscalYear {
      return "FY \(fiscalYear)"
    }

    if let normalizedPeriod, normalizedPeriod.hasPrefix("Q"), let fiscalYear {
      return "\(normalizedPeriod) \(fiscalYear)"
    }

    if let fiscalYear, !fiscalYear.isEmpty {
      return fiscalYear
    }

    return formattedMetricDate(from: date) ?? date
  }

  var formattedDate: String {
    formattedMetricDate(from: date) ?? date
  }
}

struct StockFinancialMetricEntry: Identifiable, Equatable {
  let id: String
  let title: String
  let value: Double?
  let format: StockFinancialMetricValueFormat
}

enum StockFinancialMetricValueFormat: Equatable {
  case currencyCompact
  case currency(decimals: Int)
  case multiple(decimals: Int)
  case percentFraction
  case plain(decimals: Int)
  case count
}

extension StockFinancialStatements {
  static func mock(symbol: String) -> StockFinancialStatements {
    let normalizedSymbol = symbol.uppercased()

    let balanceSheets = [
      statement(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        filingDate: "2024-11-01",
        fiscalYear: "2024",
        period: "FY",
        entries: balanceSheetEntries
      ),
      statement(
        date: "2023-09-30",
        symbol: normalizedSymbol,
        filingDate: "2023-11-03",
        fiscalYear: "2023",
        period: "FY",
        entries: scaledEntries(balanceSheetEntries, multiplier: 0.94)
      ),
      statement(
        date: "2023-12-30",
        symbol: normalizedSymbol,
        filingDate: "2024-02-02",
        fiscalYear: "2024",
        period: "Q1",
        entries: scaledEntries(balanceSheetEntries, multiplier: 0.92)
      ),
      statement(
        date: "2024-03-30",
        symbol: normalizedSymbol,
        filingDate: "2024-05-03",
        fiscalYear: "2024",
        period: "Q2",
        entries: scaledEntries(balanceSheetEntries, multiplier: 0.95)
      ),
      statement(
        date: "2024-06-29",
        symbol: normalizedSymbol,
        filingDate: "2024-08-02",
        fiscalYear: "2024",
        period: "Q3",
        entries: scaledEntries(balanceSheetEntries, multiplier: 0.97)
      ),
      statement(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        filingDate: "2024-11-01",
        fiscalYear: "2024",
        period: "Q4",
        entries: scaledEntries(balanceSheetEntries, multiplier: 1.0)
      )
    ]

    let cashFlows = [
      statement(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        filingDate: "2024-11-01",
        fiscalYear: "2024",
        period: "FY",
        entries: cashFlowEntries
      ),
      statement(
        date: "2023-09-30",
        symbol: normalizedSymbol,
        filingDate: "2023-11-03",
        fiscalYear: "2023",
        period: "FY",
        entries: scaledEntries(cashFlowEntries, multiplier: 0.95)
      ),
      statement(
        date: "2023-12-30",
        symbol: normalizedSymbol,
        filingDate: "2024-02-02",
        fiscalYear: "2024",
        period: "Q1",
        entries: scaledEntries(
          cashFlowEntries,
          multiplier: 0.22,
          overrides: [
            "cashAtBeginningOfPeriod": 29_800_000_000,
            "cashAtEndOfPeriod": 33_100_000_000,
            "netChangeInCash": 3_300_000_000
          ]
        )
      ),
      statement(
        date: "2024-03-30",
        symbol: normalizedSymbol,
        filingDate: "2024-05-03",
        fiscalYear: "2024",
        period: "Q2",
        entries: scaledEntries(
          cashFlowEntries,
          multiplier: 0.24,
          overrides: [
            "cashAtBeginningOfPeriod": 33_100_000_000,
            "cashAtEndOfPeriod": 31_500_000_000,
            "netChangeInCash": -1_600_000_000
          ]
        )
      ),
      statement(
        date: "2024-06-29",
        symbol: normalizedSymbol,
        filingDate: "2024-08-02",
        fiscalYear: "2024",
        period: "Q3",
        entries: scaledEntries(
          cashFlowEntries,
          multiplier: 0.26,
          overrides: [
            "cashAtBeginningOfPeriod": 31_500_000_000,
            "cashAtEndOfPeriod": 30_900_000_000,
            "netChangeInCash": -600_000_000
          ]
        )
      ),
      statement(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        filingDate: "2024-11-01",
        fiscalYear: "2024",
        period: "Q4",
        entries: scaledEntries(
          cashFlowEntries,
          multiplier: 0.28,
          overrides: [
            "cashAtBeginningOfPeriod": 30_900_000_000,
            "cashAtEndOfPeriod": 29_943_000_000,
            "netChangeInCash": -957_000_000
          ]
        )
      )
    ]

    let ratios = [
      metricSnapshot(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "FY",
        reportedCurrency: "USD",
        entries: ratioEntries
      ),
      metricSnapshot(
        date: "2023-09-30",
        symbol: normalizedSymbol,
        fiscalYear: "2023",
        period: "FY",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(ratioEntries, multiplier: 0.94)
      ),
      metricSnapshot(
        date: "2023-12-30",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q1",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(ratioEntries, multiplier: 0.90)
      ),
      metricSnapshot(
        date: "2024-03-30",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q2",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(ratioEntries, multiplier: 0.93)
      ),
      metricSnapshot(
        date: "2024-06-29",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q3",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(ratioEntries, multiplier: 0.96)
      ),
      metricSnapshot(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q4",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(ratioEntries, multiplier: 1.0)
      )
    ]

    let growth = [
      metricSnapshot(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "FY",
        reportedCurrency: "USD",
        entries: growthEntries
      ),
      metricSnapshot(
        date: "2023-09-30",
        symbol: normalizedSymbol,
        fiscalYear: "2023",
        period: "FY",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(growthEntries, multiplier: 0.88)
      ),
      metricSnapshot(
        date: "2023-12-30",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q1",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(growthEntries, multiplier: 0.76)
      ),
      metricSnapshot(
        date: "2024-03-30",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q2",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(growthEntries, multiplier: 0.84)
      ),
      metricSnapshot(
        date: "2024-06-29",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q3",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(growthEntries, multiplier: 0.92)
      ),
      metricSnapshot(
        date: "2024-09-28",
        symbol: normalizedSymbol,
        fiscalYear: "2024",
        period: "Q4",
        reportedCurrency: "USD",
        entries: scaledMetricEntries(growthEntries, multiplier: 1.0)
      )
    ]

    let estimates = [
      metricSnapshot(
        date: "2027-09-28",
        symbol: normalizedSymbol,
        reportedCurrency: "USD",
        entries: scaledMetricEntries(
          estimateEntries,
          multiplier: 0.88,
          overrides: [
            "numAnalystsRevenue": 13,
            "numAnalystsEps": 5
          ]
        )
      ),
      metricSnapshot(
        date: "2028-09-28",
        symbol: normalizedSymbol,
        reportedCurrency: "USD",
        entries: scaledMetricEntries(
          estimateEntries,
          multiplier: 0.94,
          overrides: [
            "numAnalystsRevenue": 15,
            "numAnalystsEps": 6
          ]
        )
      ),
      metricSnapshot(
        date: "2029-09-28",
        symbol: normalizedSymbol,
        reportedCurrency: "USD",
        entries: estimateEntries
      )
    ]

    return StockFinancialStatements(
      symbol: normalizedSymbol,
      balanceSheets: balanceSheets,
      cashFlows: cashFlows,
      ratios: ratios,
      growth: growth,
      estimates: estimates
    )
  }
}

extension CompanyProfileResponse {
  var displayName: String? {
    name?.nonEmptyTrimmed
  }

  var displayTicker: String? {
    ticker?.nonEmptyTrimmed
  }

  var websiteURL: URL? {
    guard let weburl = weburl?.nonEmptyTrimmed else { return nil }
    return URL(string: weburl)
  }

  var localizedCountryName: String? {
    guard let countryCode = country?.nonEmptyTrimmed?.uppercased() else { return nil }
    if let localized = Locale.current.localizedString(forRegionCode: countryCode), !localized.isEmpty {
      return "\(localized) (\(countryCode))"
    }
    return countryCode
  }

  var marketCapitalizationAmount: Double? {
    marketCapitalization.map { $0 * 1_000_000 }
  }

  var sharesOutstandingAmount: Double? {
    shareOutstanding.map { $0 * 1_000_000 }
  }
}

extension QuoteResponse {
  var resolvedChange: Double {
    if let change {
      return change
    }

    guard let previousClose else {
      return 0
    }

    return currentPrice - previousClose
  }

  var resolvedPercentChange: Double? {
    if let percentChange {
      return percentChange / 100
    }

    guard let previousClose, previousClose != 0 else {
      return nil
    }

    return resolvedChange / previousClose
  }
}

private extension String {
  var nonEmptyTrimmed: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

private func formattedMetricDate(from raw: String?) -> String? {
  guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
    return nil
  }

  if let date = stockBasicFinancialInputDateFormatter.date(from: raw) {
    return stockBasicFinancialOutputDateFormatter.string(from: date)
  }

  return raw
}

private let stockBasicFinancialInputDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.dateFormat = "yyyy-MM-dd"
  return formatter
}()

private let stockBasicFinancialOutputDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.locale = Locale.current
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.dateStyle = .medium
  formatter.timeStyle = .none
  return formatter
}()

private let balanceSheetEntries: [StockFinancialStatementEntry] = [
  statementEntry("cashAndCashEquivalents", "Cash & equivalents", 29_943_000_000),
  statementEntry("shortTermInvestments", "Short-term investments", 35_228_000_000),
  statementEntry("cashAndShortTermInvestments", "Cash + short-term investments", 65_171_000_000),
  statementEntry("netReceivables", "Net receivables", 66_243_000_000),
  statementEntry("accountsReceivables", "Accounts receivables", 33_410_000_000),
  statementEntry("otherReceivables", "Other receivables", 32_833_000_000),
  statementEntry("inventory", "Inventory", 7_286_000_000),
  statementEntry("prepaids", "Prepaids", 0),
  statementEntry("otherCurrentAssets", "Other current assets", 14_287_000_000),
  statementEntry("totalCurrentAssets", "Total current assets", 152_987_000_000),
  statementEntry("propertyPlantEquipmentNet", "PP&E, net", 45_680_000_000),
  statementEntry("goodwillAndIntangibleAssets", "Goodwill & intangibles", 6_955_000_000),
  statementEntry("longTermInvestments", "Long-term investments", 91_479_000_000),
  statementEntry("otherNonCurrentAssets", "Other non-current assets", 55_335_000_000),
  statementEntry("totalNonCurrentAssets", "Total non-current assets", 199_449_000_000),
  statementEntry("totalAssets", "Total assets", 352_436_000_000),
  statementEntry("accountPayables", "Accounts payables", 68_960_000_000),
  statementEntry("shortTermDebt", "Short-term debt", 10_912_000_000),
  statementEntry("otherCurrentLiabilities", "Other current liabilities", 61_336_000_000),
  statementEntry("totalCurrentLiabilities", "Total current liabilities", 141_208_000_000),
  statementEntry("longTermDebt", "Long-term debt", 86_620_000_000),
  statementEntry("otherNonCurrentLiabilities", "Other non-current liabilities", 23_010_000_000),
  statementEntry("totalNonCurrentLiabilities", "Total non-current liabilities", 109_630_000_000),
  statementEntry("totalLiabilities", "Total liabilities", 250_838_000_000),
  statementEntry("commonStock", "Common stock", 83_276_000_000),
  statementEntry("retainedEarnings", "Retained earnings", -19_154_000_000),
  statementEntry("accumulatedOtherComprehensiveIncomeLoss", "Accum. OCI", -7_172_000_000),
  statementEntry("totalStockholdersEquity", "Total stockholders equity", 101_598_000_000),
  statementEntry("totalEquity", "Total equity", 101_598_000_000),
  statementEntry(
    "totalLiabilitiesAndStockholdersEquity",
    "Total liabilities + equity",
    352_436_000_000
  )
]

private let cashFlowEntries: [StockFinancialStatementEntry] = [
  statementEntry("netIncome", "Net income", 93_736_000_000),
  statementEntry("depreciationAndAmortization", "D&A", 11_445_000_000),
  statementEntry("deferredIncomeTax", "Deferred income tax", 0),
  statementEntry("stockBasedCompensation", "Stock-based comp", 11_688_000_000),
  statementEntry("changeInWorkingCapital", "Change in working capital", 3_651_000_000),
  statementEntry("accountsReceivables", "Accounts receivables", -5_144_000_000),
  statementEntry("inventory", "Inventory", -1_046_000_000),
  statementEntry("accountsPayables", "Accounts payables", 6_020_000_000),
  statementEntry("otherWorkingCapital", "Other working capital", 3_821_000_000),
  statementEntry("otherNonCashItems", "Other non-cash items", -2_266_000_000),
  statementEntry(
    "netCashProvidedByOperatingActivities",
    "Net cash from operating activities",
    118_254_000_000
  ),
  statementEntry(
    "investmentsInPropertyPlantAndEquipment",
    "Investments in PP&E",
    -9_447_000_000
  ),
  statementEntry("acquisitionsNet", "Acquisitions, net", 0),
  statementEntry("purchasesOfInvestments", "Purchases of investments", -48_656_000_000),
  statementEntry("salesMaturitiesOfInvestments", "Sales/maturities of investments", 62_346_000_000),
  statementEntry("otherInvestingActivities", "Other investing activities", -1_308_000_000),
  statementEntry(
    "netCashProvidedByInvestingActivities",
    "Net cash from investing activities",
    2_935_000_000
  ),
  statementEntry("netDebtIssuance", "Net debt issuance", -5_998_000_000),
  statementEntry("longTermNetDebtIssuance", "Long-term net debt issuance", -9_958_000_000),
  statementEntry("shortTermNetDebtIssuance", "Short-term net debt issuance", 3_960_000_000),
  statementEntry("netStockIssuance", "Net stock issuance", -94_949_000_000),
  statementEntry("netCommonStockIssuance", "Net common stock issuance", -94_949_000_000),
  statementEntry("commonStockIssuance", "Common stock issuance", 0),
  statementEntry("commonStockRepurchased", "Common stock repurchased", -94_949_000_000),
  statementEntry("netPreferredStockIssuance", "Net preferred stock issuance", 0),
  statementEntry("netDividendsPaid", "Net dividends paid", -15_234_000_000),
  statementEntry("commonDividendsPaid", "Common dividends paid", -15_234_000_000),
  statementEntry("preferredDividendsPaid", "Preferred dividends paid", 0),
  statementEntry("otherFinancingActivities", "Other financing activities", -5_802_000_000),
  statementEntry(
    "netCashProvidedByFinancingActivities",
    "Net cash from financing activities",
    -121_983_000_000
  ),
  statementEntry("effectOfForexChangesOnCash", "FX effect on cash", 0),
  statementEntry("netChangeInCash", "Net change in cash", -794_000_000),
  statementEntry("cashAtEndOfPeriod", "Cash at end of period", 29_943_000_000),
  statementEntry("cashAtBeginningOfPeriod", "Cash at beginning of period", 30_737_000_000),
  statementEntry("operatingCashFlow", "Operating cash flow", 118_254_000_000),
  statementEntry("capitalExpenditure", "Capital expenditure", -9_447_000_000),
  statementEntry("freeCashFlow", "Free cash flow", 108_807_000_000),
  statementEntry("incomeTaxesPaid", "Income taxes paid", 26_102_000_000),
  statementEntry("interestPaid", "Interest paid", 0)
]

private let ratioEntries: [StockFinancialMetricEntry] = [
  metricEntry("marketCap", "Market cap", 3_495_160_329_570, .currencyCompact),
  metricEntry("enterpriseValue", "Enterprise value", 3_571_846_329_570, .currencyCompact),
  metricEntry("evToSales", "EV / Sales", 9.134339201273542, .multiple(decimals: 2)),
  metricEntry("evToOperatingCashFlow", "EV / Operating CF", 30.204866893043786, .multiple(decimals: 2)),
  metricEntry("evToFreeCashFlow", "EV / Free CF", 32.82735788662494, .multiple(decimals: 2)),
  metricEntry("evToEBITDA", "EV / EBITDA", 26.524727497716487, .multiple(decimals: 2)),
  metricEntry("netDebtToEBITDA", "Net debt / EBITDA", 0.5694744580836323, .multiple(decimals: 2)),
  metricEntry("currentRatio", "Current ratio", 0.8673125765340832, .plain(decimals: 2)),
  metricEntry("incomeQuality", "Income quality", 1.2615643936161134, .plain(decimals: 2)),
  metricEntry("grahamNumber", "Graham number", 22.587017267616833, .currency(decimals: 2)),
  metricEntry("grahamNetNet", "Graham net-net", -12.352478525015636, .currency(decimals: 2)),
  metricEntry("taxBurden", "Tax burden", 0.7590881483581001, .multiple(decimals: 2)),
  metricEntry("interestBurden", "Interest burden", 1.0021831580314244, .multiple(decimals: 2)),
  metricEntry("workingCapital", "Working capital", -23_405_000_000, .currencyCompact),
  metricEntry("investedCapital", "Invested capital", 22_275_000_000, .currencyCompact),
  metricEntry("returnOnAssets", "Return on assets", 0.25682503150857583, .percentFraction),
  metricEntry("operatingReturnOnAssets", "Operating ROA", 0.3434290787011036, .percentFraction),
  metricEntry("returnOnTangibleAssets", "Return on tangible assets", 0.25682503150857583, .percentFraction),
  metricEntry("returnOnEquity", "Return on equity", 1.6459350307287095, .percentFraction),
  metricEntry("returnOnInvestedCapital", "Return on invested capital", 0.4430708117427921, .percentFraction),
  metricEntry("returnOnCapitalEmployed", "Return on capital employed", 0.6533607652660827, .percentFraction),
  metricEntry("earningsYield", "Earnings yield", 0.026818798327209237, .percentFraction),
  metricEntry("freeCashFlowYield", "Free cash flow yield", 0.03113076074921754, .percentFraction),
  metricEntry("capexToOperatingCashFlow", "Capex / operating CF", 0.07988736110406414, .percentFraction),
  metricEntry("capexToDepreciation", "Capex / depreciation", 0.8254259501965924, .multiple(decimals: 2)),
  metricEntry("capexToRevenue", "Capex / revenue", 0.02415896275269477, .percentFraction),
  metricEntry("salesGeneralAndAdministrativeToRevenue", "SG&A / revenue", 0, .percentFraction),
  metricEntry("researchAndDevelopementToRevenue", "R&D / revenue", 0.08022299794136074, .percentFraction),
  metricEntry("stockBasedCompensationToRevenue", "SBC / revenue", 0.02988990755303234, .percentFraction),
  metricEntry("intangiblesToTotalAssets", "Intangibles / total assets", 0, .percentFraction),
  metricEntry("averageReceivables", "Average receivables", 63_614_000_000, .currencyCompact),
  metricEntry("averagePayables", "Average payables", 65_785_500_000, .currencyCompact),
  metricEntry("averageInventory", "Average inventory", 6_808_500_000, .currencyCompact),
  metricEntry("daysOfSalesOutstanding", "Days sales outstanding", 61.83255974529134, .plain(decimals: 1)),
  metricEntry("daysOfPayablesOutstanding", "Days payables outstanding", 119.65847721913745, .plain(decimals: 1)),
  metricEntry("daysOfInventoryOutstanding", "Days inventory outstanding", 12.642570548414087, .plain(decimals: 1)),
  metricEntry("operatingCycle", "Operating cycle", 74.47513029370543, .plain(decimals: 1)),
  metricEntry("cashConversionCycle", "Cash conversion cycle", -45.18334692543202, .plain(decimals: 1)),
  metricEntry("freeCashFlowToEquity", "Free cash flow to equity", 32_121_000_000, .currencyCompact),
  metricEntry("freeCashFlowToFirm", "Free cash flow to firm", 117_192_805_288.09166, .currencyCompact),
  metricEntry("tangibleAssetValue", "Tangible asset value", 56_950_000_000, .currencyCompact),
  metricEntry("netCurrentAssetValue", "Net current asset value", -155_043_000_000, .currencyCompact)
]

private let growthEntries: [StockFinancialMetricEntry] = [
  metricEntry("revenueGrowth", "Revenue growth", 0.020219940775141214, .percentFraction),
  metricEntry("grossProfitGrowth", "Gross profit growth", 0.06819471705252206, .percentFraction),
  metricEntry("ebitgrowth", "EBIT growth", 0.07799581805933456, .percentFraction),
  metricEntry("operatingIncomeGrowth", "Operating income growth", 0.07799581805933456, .percentFraction),
  metricEntry("netIncomeGrowth", "Net income growth", -0.033599670086086914, .percentFraction),
  metricEntry("epsgrowth", "EPS growth", -0.008116883116883088, .percentFraction),
  metricEntry("epsdilutedGrowth", "Diluted EPS growth", -0.008156606851549727, .percentFraction),
  metricEntry("weightedAverageSharesGrowth", "Weighted avg shares growth", -0.02543458616683152, .percentFraction),
  metricEntry("weightedAverageSharesDilutedGrowth", "Diluted shares growth", -0.02557791606880283, .percentFraction),
  metricEntry("dividendsPerShareGrowth", "Dividend/share growth", 0.040371570095532654, .percentFraction),
  metricEntry("operatingCashFlowGrowth", "Operating cash flow growth", 0.06975566069312394, .percentFraction),
  metricEntry("receivablesGrowth", "Receivables growth", 0.08621792243994425, .percentFraction),
  metricEntry("inventoryGrowth", "Inventory growth", 0.15084504817564365, .percentFraction),
  metricEntry("assetGrowth", "Asset growth", 0.035160515396374756, .percentFraction),
  metricEntry("bookValueperShareGrowth", "Book value/share growth", -0.059693251557224776, .percentFraction),
  metricEntry("debtGrowth", "Debt growth", -0.0401393489845888, .percentFraction),
  metricEntry("rdexpenseGrowth", "R&D expense growth", 0.04863780712017383, .percentFraction),
  metricEntry("sgaexpensesGrowth", "SG&A expense growth", 0.04672709770575967, .percentFraction),
  metricEntry("freeCashFlowGrowth", "Free cash flow growth", 0.092615279562982, .percentFraction),
  metricEntry("tenYRevenueGrowthPerShare", "10Y revenue/share growth", 2.3937532854122625, .percentFraction),
  metricEntry("fiveYRevenueGrowthPerShare", "5Y revenue/share growth", 0.8093292228858464, .percentFraction),
  metricEntry("threeYRevenueGrowthPerShare", "3Y revenue/share growth", 0.163506592883552, .percentFraction),
  metricEntry("tenYOperatingCFGrowthPerShare", "10Y operating CF/share growth", 2.1417809176982403, .percentFraction),
  metricEntry("fiveYOperatingCFGrowthPerShare", "5Y operating CF/share growth", 1.051533221923415, .percentFraction),
  metricEntry("threeYOperatingCFGrowthPerShare", "3Y operating CF/share growth", 0.23720294833900227, .percentFraction),
  metricEntry("tenYNetIncomeGrowthPerShare", "10Y net income/share growth", 2.76381558093543, .percentFraction),
  metricEntry("fiveYNetIncomeGrowthPerShare", "5Y net income/share growth", 1.0421744314966246, .percentFraction),
  metricEntry("threeYNetIncomeGrowthPerShare", "3Y net income/share growth", 0.07761907162786884, .percentFraction),
  metricEntry("tenYShareholdersEquityGrowthPerShare", "10Y equity/share growth", -0.19003774225234785, .percentFraction),
  metricEntry("fiveYShareholdersEquityGrowthPerShare", "5Y equity/share growth", -0.24235004889283715, .percentFraction),
  metricEntry("threeYShareholdersEquityGrowthPerShare", "3Y equity/share growth", -0.017459858915902907, .percentFraction),
  metricEntry("tenYDividendperShareGrowthPerShare", "10Y dividend/share growth", 1.1722201809466772, .percentFraction),
  metricEntry("fiveYDividendperShareGrowthPerShare", "5Y dividend/share growth", 0.29890046876764864, .percentFraction),
  metricEntry("threeYDividendperShareGrowthPerShare", "3Y dividend/share growth", 0.14617932692103452, .percentFraction),
  metricEntry("ebitdaGrowth", "EBITDA growth", nil, .percentFraction),
  metricEntry("growthCapitalExpenditure", "Capex growth", nil, .percentFraction),
  metricEntry("tenYBottomLineNetIncomeGrowthPerShare", "10Y bottom-line/share growth", nil, .percentFraction),
  metricEntry("fiveYBottomLineNetIncomeGrowthPerShare", "5Y bottom-line/share growth", nil, .percentFraction),
  metricEntry("threeYBottomLineNetIncomeGrowthPerShare", "3Y bottom-line/share growth", nil, .percentFraction)
]

private let estimateEntries: [StockFinancialMetricEntry] = [
  metricEntry("revenueLow", "Revenue low", 483_092_500_000, .currencyCompact),
  metricEntry("revenueHigh", "Revenue high", 483_093_500_000, .currencyCompact),
  metricEntry("revenueAvg", "Revenue avg", 483_093_000_000, .currencyCompact),
  metricEntry("ebitdaLow", "EBITDA low", 155_952_166_036, .currencyCompact),
  metricEntry("ebitdaHigh", "EBITDA high", 155_952_488_856, .currencyCompact),
  metricEntry("ebitdaAvg", "EBITDA avg", 155_952_327_446, .currencyCompact),
  metricEntry("ebitLow", "EBIT low", 140_628_295_747, .currencyCompact),
  metricEntry("ebitHigh", "EBIT high", 140_628_586_847, .currencyCompact),
  metricEntry("ebitAvg", "EBIT avg", 140_628_441_297, .currencyCompact),
  metricEntry("netIncomeLow", "Net income low", 139_446_957_701, .currencyCompact),
  metricEntry("netIncomeHigh", "Net income high", 157_185_372_990, .currencyCompact),
  metricEntry("netIncomeAvg", "Net income avg", 149_150_359_609, .currencyCompact),
  metricEntry("sgaExpenseLow", "SG&A expense low", 31_694_652_812, .currencyCompact),
  metricEntry("sgaExpenseHigh", "SG&A expense high", 31_694_718_420, .currencyCompact),
  metricEntry("sgaExpenseAvg", "SG&A expense avg", 31_694_685_616, .currencyCompact),
  metricEntry("epsAvg", "EPS avg", 9.68, .currency(decimals: 2)),
  metricEntry("epsHigh", "EPS high", 10.20148, .currency(decimals: 2)),
  metricEntry("epsLow", "EPS low", 9.05024, .currency(decimals: 2)),
  metricEntry("numAnalystsRevenue", "Revenue analysts", 16, .count),
  metricEntry("numAnalystsEps", "EPS analysts", 6, .count)
]

private func statement(
  date: String,
  symbol: String,
  filingDate: String,
  fiscalYear: String,
  period: String,
  entries: [StockFinancialStatementEntry]
) -> StockFinancialStatement {
  StockFinancialStatement(
    date: date,
    symbol: symbol,
    reportedCurrency: "USD",
    cik: "0000320193",
    filingDate: filingDate,
    acceptedDate: "\(filingDate) 06:01:36",
    fiscalYear: fiscalYear,
    period: period,
    entries: entries
  )
}

private func statementEntry(
  _ id: String,
  _ title: String,
  _ value: Double
) -> StockFinancialStatementEntry {
  StockFinancialStatementEntry(id: id, title: title, value: value)
}

private func metricSnapshot(
  date: String,
  symbol: String,
  fiscalYear: String? = nil,
  period: String? = nil,
  reportedCurrency: String? = nil,
  entries: [StockFinancialMetricEntry]
) -> StockFinancialMetricSnapshot {
  StockFinancialMetricSnapshot(
    date: date,
    symbol: symbol,
    fiscalYear: fiscalYear,
    period: period,
    reportedCurrency: reportedCurrency,
    entries: entries
  )
}

private func metricEntry(
  _ id: String,
  _ title: String,
  _ value: Double?,
  _ format: StockFinancialMetricValueFormat
) -> StockFinancialMetricEntry {
  StockFinancialMetricEntry(id: id, title: title, value: value, format: format)
}

private func scaledEntries(
  _ entries: [StockFinancialStatementEntry],
  multiplier: Double,
  overrides: [String: Double] = [:]
) -> [StockFinancialStatementEntry] {
  entries.map { entry in
    let scaledValue = overrides[entry.id] ?? roundedToNearestMillion(entry.value * multiplier)
    return StockFinancialStatementEntry(
      id: entry.id,
      title: entry.title,
      value: scaledValue
    )
  }
}

private func roundedToNearestMillion(_ value: Double) -> Double {
  (value / 1_000_000).rounded() * 1_000_000
}

private func scaledMetricEntries(
  _ entries: [StockFinancialMetricEntry],
  multiplier: Double,
  overrides: [String: Double] = [:]
) -> [StockFinancialMetricEntry] {
  entries.map { entry in
    let value: Double?
    if let override = overrides[entry.id] {
      value = override
    } else if let entryValue = entry.value {
      value = scaledMetricValue(entryValue, format: entry.format, multiplier: multiplier)
    } else {
      value = nil
    }

    return StockFinancialMetricEntry(
      id: entry.id,
      title: entry.title,
      value: value,
      format: entry.format
    )
  }
}

private func scaledMetricValue(
  _ value: Double,
  format: StockFinancialMetricValueFormat,
  multiplier: Double
) -> Double {
  switch format {
  case .currencyCompact:
    return roundedToNearestMillion(value * multiplier)
  case let .currency(decimals):
    return rounded(value * multiplier, decimals: decimals)
  case .multiple, .percentFraction, .plain:
    return value * multiplier
  case .count:
    return max(0, (value * multiplier).rounded())
  }
}

private func rounded(_ value: Double, decimals: Int) -> Double {
  let factor = pow(10, Double(decimals))
  return (value * factor).rounded() / factor
}

// MARK: - Nonisolated Codable conformances
// Required because SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would otherwise
// make synthesized Codable methods @MainActor-isolated, breaking Sendable call sites.

nonisolated extension YearlyProjection: Codable {}
nonisolated extension StockAnalysisMetrics: Codable {}
nonisolated extension StockAnalystConsensus: Codable {}