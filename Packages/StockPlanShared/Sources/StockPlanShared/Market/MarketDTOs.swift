// swiftlint:disable file_length — DTO catalogue; splitting is a separate refactor.
import Foundation

public struct StockDetailsResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let company: String
    public let latestPrice: Double
    public let changePercent: Double

    public init(symbol: String, company: String, latestPrice: Double, changePercent: Double) {
        self.symbol = symbol
        self.company = company
        self.latestPrice = latestPrice
        self.changePercent = changePercent
    }
}

public struct QuoteResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let currency: String
    public let currentPrice: Double
    public let change: Double?
    public let percentChange: Double?
    public let high: Double?
    public let low: Double?
    public let open: Double?
    public let previousClose: Double?
    public let timestamp: Double

    enum CodingKeys: String, CodingKey {
        case symbol, currency
        case currentPrice = "c"
        case change = "d"
        case percentChange = "dp"
        case high = "h"
        case low = "l"
        case open = "o"
        case previousClose = "pc"
        case timestamp = "t"
    }

    public init(
        symbol: String,
        currency: String,
        currentPrice: Double,
        change: Double? = nil,
        percentChange: Double? = nil,
        high: Double? = nil,
        low: Double? = nil,
        open: Double? = nil,
        previousClose: Double? = nil,
        timestamp: Double
    ) {
        self.symbol = symbol
        self.currency = currency
        self.currentPrice = currentPrice
        self.change = change
        self.percentChange = percentChange
        self.high = high
        self.low = low
        self.open = open
        self.previousClose = previousClose
        self.timestamp = timestamp
    }

    public var isPositiveSession: Bool {
        (change ?? 0) >= 0
    }

    public var rangeProgress: Double {
        guard let high, let low, high > low else { return 0.5 }
        let progress = (currentPrice - low) / (high - low)
        return min(max(progress, 0), 1)
    }
}

public struct CompanyProfileResponse: Codable, Sendable, Equatable {
    public let country: String?
    public let currency: String?
    public let estimateCurrency: String?
    public let exchange: String?
    public let finnhubIndustry: String?
    public let ipo: String?
    public let logo: String?
    public let marketCapitalization: Double?
    public let name: String?
    public let phone: String?
    public let shareOutstanding: Double?
    public let ticker: String?
    public let weburl: String?
    public let lastUpdated: String? // ISO8601 timestamp for caching

    public init(
        country: String?,
        currency: String?,
        estimateCurrency: String?,
        exchange: String?,
        finnhubIndustry: String?,
        ipo: String?,
        logo: String?,
        marketCapitalization: Double?,
        name: String?,
        phone: String?,
        shareOutstanding: Double?,
        ticker: String?,
        weburl: String?,
        lastUpdated: String? = nil
    ) {
        self.country = country
        self.currency = currency
        self.estimateCurrency = estimateCurrency
        self.exchange = exchange
        self.finnhubIndustry = finnhubIndustry
        self.ipo = ipo
        self.logo = logo
        self.marketCapitalization = marketCapitalization
        self.name = name
        self.phone = phone
        self.shareOutstanding = shareOutstanding
        self.ticker = ticker
        self.weburl = weburl
        self.lastUpdated = lastUpdated
    }
}

public struct PriceBarResponse: Codable, Sendable, Equatable {
    public let date: String
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int?

    public init(date: String, open: Double, high: Double, low: Double, close: Double, volume: Int?) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

public struct HistoryResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let currency: String
    public let bars: [PriceBarResponse]

    public init(symbol: String, currency: String, bars: [PriceBarResponse]) {
        self.symbol = symbol
        self.currency = currency
        self.bars = bars
    }
}

public struct SearchResultResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let name: String
    public let exchange: String
    public let currency: String
    public let conid: String

    public init(symbol: String, name: String, exchange: String, currency: String, conid: String) {
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.currency = currency
        self.conid = conid
    }
}

public struct FxRateResponse: Codable, Sendable, Equatable {
    public let base: String
    public let quote: String
    public let rate: Double
    public let date: String

    public init(base: String, quote: String, rate: Double, date: String) {
        self.base = base
        self.quote = quote
        self.rate = rate
        self.date = date
    }
}

public struct QuoteBatchResponse: Codable, Sendable, Equatable {
    public let quotes: [QuoteResponse]

    public init(quotes: [QuoteResponse]) {
        self.quotes = quotes
    }
}

public enum BasicFinancialMetricValue: Codable, Sendable, Equatable {
    case number(Double)
    case string(String)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported basic financial metric value."
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct BasicFinancialSeriesPoint: Codable, Sendable, Equatable {
    public let period: String
    public let value: Double

    enum CodingKeys: String, CodingKey {
        case period
        case value = "v"
    }

    public init(period: String, value: Double) {
        self.period = period
        self.value = value
    }
}

public struct BasicFinancialsResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let metricType: String
    public let metric: [String: BasicFinancialMetricValue]
    public let series: [String: [String: [BasicFinancialSeriesPoint]]]

    public init(
        symbol: String,
        metricType: String,
        metric: [String: BasicFinancialMetricValue],
        series: [String: [String: [BasicFinancialSeriesPoint]]]
    ) {
        self.symbol = symbol
        self.metricType = metricType
        self.metric = metric
        self.series = series
    }
}

public struct RatiosTTMResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let grossProfitMarginTTM: Double?
    public let ebitMarginTTM: Double?
    public let ebitdaMarginTTM: Double?
    public let operatingProfitMarginTTM: Double?
    public let pretaxProfitMarginTTM: Double?
    public let continuousOperationsProfitMarginTTM: Double?
    public let netProfitMarginTTM: Double?
    public let bottomLineProfitMarginTTM: Double?
    public let receivablesTurnoverTTM: Double?
    public let payablesTurnoverTTM: Double?
    public let inventoryTurnoverTTM: Double?
    public let fixedAssetTurnoverTTM: Double?
    public let assetTurnoverTTM: Double?
    public let currentRatioTTM: Double?
    public let quickRatioTTM: Double?
    public let solvencyRatioTTM: Double?
    public let cashRatioTTM: Double?
    public let priceToEarningsRatioTTM: Double?
    public let priceToEarningsGrowthRatioTTM: Double?
    public let forwardPriceToEarningsGrowthRatioTTM: Double?
    public let priceToBookRatioTTM: Double?
    public let priceToSalesRatioTTM: Double?
    public let priceToFreeCashFlowRatioTTM: Double?
    public let priceToOperatingCashFlowRatioTTM: Double?
    public let debtToAssetsRatioTTM: Double?
    public let debtToEquityRatioTTM: Double?
    public let debtToCapitalRatioTTM: Double?
    public let longTermDebtToCapitalRatioTTM: Double?
    public let financialLeverageRatioTTM: Double?
    public let workingCapitalTurnoverRatioTTM: Double?
    public let operatingCashFlowRatioTTM: Double?
    public let operatingCashFlowSalesRatioTTM: Double?
    public let freeCashFlowOperatingCashFlowRatioTTM: Double?
    public let debtServiceCoverageRatioTTM: Double?
    public let interestCoverageRatioTTM: Double?
    public let shortTermOperatingCashFlowCoverageRatioTTM: Double?
    public let operatingCashFlowCoverageRatioTTM: Double?
    public let capitalExpenditureCoverageRatioTTM: Double?
    public let dividendPaidAndCapexCoverageRatioTTM: Double?
    public let dividendPayoutRatioTTM: Double?
    public let dividendYieldTTM: Double?
    public let enterpriseValueTTM: Double?
    public let revenuePerShareTTM: Double?
    public let netIncomePerShareTTM: Double?
    public let interestDebtPerShareTTM: Double?
    public let cashPerShareTTM: Double?
    public let bookValuePerShareTTM: Double?
    public let tangibleBookValuePerShareTTM: Double?
    public let shareholdersEquityPerShareTTM: Double?
    public let operatingCashFlowPerShareTTM: Double?
    public let capexPerShareTTM: Double?
    public let freeCashFlowPerShareTTM: Double?
    public let netIncomePerEBTTTM: Double?
    public let ebtPerEbitTTM: Double?
    public let priceToFairValueTTM: Double?
    public let debtToMarketCapTTM: Double?
    public let effectiveTaxRateTTM: Double?
    public let enterpriseValueMultipleTTM: Double?

    public init(
        symbol: String,
        grossProfitMarginTTM: Double?,
        ebitMarginTTM: Double?,
        ebitdaMarginTTM: Double?,
        operatingProfitMarginTTM: Double?,
        pretaxProfitMarginTTM: Double?,
        continuousOperationsProfitMarginTTM: Double?,
        netProfitMarginTTM: Double?,
        bottomLineProfitMarginTTM: Double?,
        receivablesTurnoverTTM: Double?,
        payablesTurnoverTTM: Double?,
        inventoryTurnoverTTM: Double?,
        fixedAssetTurnoverTTM: Double?,
        assetTurnoverTTM: Double?,
        currentRatioTTM: Double?,
        quickRatioTTM: Double?,
        solvencyRatioTTM: Double?,
        cashRatioTTM: Double?,
        priceToEarningsRatioTTM: Double?,
        priceToEarningsGrowthRatioTTM: Double?,
        forwardPriceToEarningsGrowthRatioTTM: Double?,
        priceToBookRatioTTM: Double?,
        priceToSalesRatioTTM: Double?,
        priceToFreeCashFlowRatioTTM: Double?,
        priceToOperatingCashFlowRatioTTM: Double?,
        debtToAssetsRatioTTM: Double?,
        debtToEquityRatioTTM: Double?,
        debtToCapitalRatioTTM: Double?,
        longTermDebtToCapitalRatioTTM: Double?,
        financialLeverageRatioTTM: Double?,
        workingCapitalTurnoverRatioTTM: Double?,
        operatingCashFlowRatioTTM: Double?,
        operatingCashFlowSalesRatioTTM: Double?,
        freeCashFlowOperatingCashFlowRatioTTM: Double?,
        debtServiceCoverageRatioTTM: Double?,
        interestCoverageRatioTTM: Double?,
        shortTermOperatingCashFlowCoverageRatioTTM: Double?,
        operatingCashFlowCoverageRatioTTM: Double?,
        capitalExpenditureCoverageRatioTTM: Double?,
        dividendPaidAndCapexCoverageRatioTTM: Double?,
        dividendPayoutRatioTTM: Double?,
        dividendYieldTTM: Double?,
        enterpriseValueTTM: Double?,
        revenuePerShareTTM: Double?,
        netIncomePerShareTTM: Double?,
        interestDebtPerShareTTM: Double?,
        cashPerShareTTM: Double?,
        bookValuePerShareTTM: Double?,
        tangibleBookValuePerShareTTM: Double?,
        shareholdersEquityPerShareTTM: Double?,
        operatingCashFlowPerShareTTM: Double?,
        capexPerShareTTM: Double?,
        freeCashFlowPerShareTTM: Double?,
        netIncomePerEBTTTM: Double?,
        ebtPerEbitTTM: Double?,
        priceToFairValueTTM: Double?,
        debtToMarketCapTTM: Double?,
        effectiveTaxRateTTM: Double?,
        enterpriseValueMultipleTTM: Double?
    ) {
        self.symbol = symbol
        self.grossProfitMarginTTM = grossProfitMarginTTM
        self.ebitMarginTTM = ebitMarginTTM
        self.ebitdaMarginTTM = ebitdaMarginTTM
        self.operatingProfitMarginTTM = operatingProfitMarginTTM
        self.pretaxProfitMarginTTM = pretaxProfitMarginTTM
        self.continuousOperationsProfitMarginTTM = continuousOperationsProfitMarginTTM
        self.netProfitMarginTTM = netProfitMarginTTM
        self.bottomLineProfitMarginTTM = bottomLineProfitMarginTTM
        self.receivablesTurnoverTTM = receivablesTurnoverTTM
        self.payablesTurnoverTTM = payablesTurnoverTTM
        self.inventoryTurnoverTTM = inventoryTurnoverTTM
        self.fixedAssetTurnoverTTM = fixedAssetTurnoverTTM
        self.assetTurnoverTTM = assetTurnoverTTM
        self.currentRatioTTM = currentRatioTTM
        self.quickRatioTTM = quickRatioTTM
        self.solvencyRatioTTM = solvencyRatioTTM
        self.cashRatioTTM = cashRatioTTM
        self.priceToEarningsRatioTTM = priceToEarningsRatioTTM
        self.priceToEarningsGrowthRatioTTM = priceToEarningsGrowthRatioTTM
        self.forwardPriceToEarningsGrowthRatioTTM = forwardPriceToEarningsGrowthRatioTTM
        self.priceToBookRatioTTM = priceToBookRatioTTM
        self.priceToSalesRatioTTM = priceToSalesRatioTTM
        self.priceToFreeCashFlowRatioTTM = priceToFreeCashFlowRatioTTM
        self.priceToOperatingCashFlowRatioTTM = priceToOperatingCashFlowRatioTTM
        self.debtToAssetsRatioTTM = debtToAssetsRatioTTM
        self.debtToEquityRatioTTM = debtToEquityRatioTTM
        self.debtToCapitalRatioTTM = debtToCapitalRatioTTM
        self.longTermDebtToCapitalRatioTTM = longTermDebtToCapitalRatioTTM
        self.financialLeverageRatioTTM = financialLeverageRatioTTM
        self.workingCapitalTurnoverRatioTTM = workingCapitalTurnoverRatioTTM
        self.operatingCashFlowRatioTTM = operatingCashFlowRatioTTM
        self.operatingCashFlowSalesRatioTTM = operatingCashFlowSalesRatioTTM
        self.freeCashFlowOperatingCashFlowRatioTTM = freeCashFlowOperatingCashFlowRatioTTM
        self.debtServiceCoverageRatioTTM = debtServiceCoverageRatioTTM
        self.interestCoverageRatioTTM = interestCoverageRatioTTM
        self.shortTermOperatingCashFlowCoverageRatioTTM = shortTermOperatingCashFlowCoverageRatioTTM
        self.operatingCashFlowCoverageRatioTTM = operatingCashFlowCoverageRatioTTM
        self.capitalExpenditureCoverageRatioTTM = capitalExpenditureCoverageRatioTTM
        self.dividendPaidAndCapexCoverageRatioTTM = dividendPaidAndCapexCoverageRatioTTM
        self.dividendPayoutRatioTTM = dividendPayoutRatioTTM
        self.dividendYieldTTM = dividendYieldTTM
        self.enterpriseValueTTM = enterpriseValueTTM
        self.revenuePerShareTTM = revenuePerShareTTM
        self.netIncomePerShareTTM = netIncomePerShareTTM
        self.interestDebtPerShareTTM = interestDebtPerShareTTM
        self.cashPerShareTTM = cashPerShareTTM
        self.bookValuePerShareTTM = bookValuePerShareTTM
        self.tangibleBookValuePerShareTTM = tangibleBookValuePerShareTTM
        self.shareholdersEquityPerShareTTM = shareholdersEquityPerShareTTM
        self.operatingCashFlowPerShareTTM = operatingCashFlowPerShareTTM
        self.capexPerShareTTM = capexPerShareTTM
        self.freeCashFlowPerShareTTM = freeCashFlowPerShareTTM
        self.netIncomePerEBTTTM = netIncomePerEBTTTM
        self.ebtPerEbitTTM = ebtPerEbitTTM
        self.priceToFairValueTTM = priceToFairValueTTM
        self.debtToMarketCapTTM = debtToMarketCapTTM
        self.effectiveTaxRateTTM = effectiveTaxRateTTM
        self.enterpriseValueMultipleTTM = enterpriseValueMultipleTTM
    }
}

public struct BalanceSheetStatementResponse: Codable, Sendable, Equatable {
    public let date: String
    public let symbol: String
    public let reportedCurrency: String?
    public let cik: String?
    public let filingDate: String?
    public let acceptedDate: String?
    public let fiscalYear: String?
    public let period: String?
    public let cashAndCashEquivalents: Double?
    public let shortTermInvestments: Double?
    public let cashAndShortTermInvestments: Double?
    public let netReceivables: Double?
    public let accountsReceivables: Double?
    public let otherReceivables: Double?
    public let inventory: Double?
    public let prepaids: Double?
    public let otherCurrentAssets: Double?
    public let totalCurrentAssets: Double?
    public let propertyPlantEquipmentNet: Double?
    public let goodwill: Double?
    public let intangibleAssets: Double?
    public let goodwillAndIntangibleAssets: Double?
    public let longTermInvestments: Double?
    public let taxAssets: Double?
    public let otherNonCurrentAssets: Double?
    public let totalNonCurrentAssets: Double?
    public let otherAssets: Double?
    public let totalAssets: Double?
    public let totalPayables: Double?
    public let accountPayables: Double?
    public let otherPayables: Double?
    public let accruedExpenses: Double?
    public let shortTermDebt: Double?
    public let capitalLeaseOblationsCurrent: Double? // fixed typo in your original
    public let taxPayables: Double?
    public let deferredRevenue: Double?
    public let otherCurrentLiabilities: Double?
    public let totalCurrentLiabilities: Double?
    public let longTermDebt: Double?
    public let deferredRevenueNonCurrent: Double?
    public let deferredTaxLiabilitiesNonCurrent: Double?
    public let otherNonCurrentLiabilities: Double?
    public let totalNonCurrentLiabilities: Double?
    public let otherLiabilities: Double?
    public let capitalLeaseObligations: Double?
    public let totalLiabilities: Double?
    public let treasuryStock: Double?
    public let preferredStock: Double?
    public let commonStock: Double?
    public let retainedEarnings: Double?
    public let additionalPaidInCapital: Double?
    public let accumulatedOtherComprehensiveIncomeLoss: Double?
    public let otherTotalStockholdersEquity: Double?
    public let totalStockholdersEquity: Double?
    public let totalEquity: Double?
    public let minorityInterest: Double?
    public let totalLiabilitiesAndTotalEquity: Double?
    public let totalInvestments: Double?
    public let totalDebt: Double?
    public let netDebt: Double?

    public init(
        date: String,
        symbol: String,
        reportedCurrency: String?,
        cik: String?,
        filingDate: String?,
        acceptedDate: String?,
        fiscalYear: String?,
        period: String?,
        cashAndCashEquivalents: Double?,
        shortTermInvestments: Double?,
        cashAndShortTermInvestments: Double?,
        netReceivables: Double?,
        accountsReceivables: Double?,
        otherReceivables: Double?,
        inventory: Double?,
        prepaids: Double?,
        otherCurrentAssets: Double?,
        totalCurrentAssets: Double?,
        propertyPlantEquipmentNet: Double?,
        goodwill: Double?,
        intangibleAssets: Double?,
        goodwillAndIntangibleAssets: Double?,
        longTermInvestments: Double?,
        taxAssets: Double?,
        otherNonCurrentAssets: Double?,
        totalNonCurrentAssets: Double?,
        otherAssets: Double?,
        totalAssets: Double?,
        totalPayables: Double?,
        accountPayables: Double?,
        otherPayables: Double?,
        accruedExpenses: Double?,
        shortTermDebt: Double?,
        capitalLeaseOblationsCurrent: Double?,
        taxPayables: Double?,
        deferredRevenue: Double?,
        otherCurrentLiabilities: Double?,
        totalCurrentLiabilities: Double?,
        longTermDebt: Double?,
        deferredRevenueNonCurrent: Double?,
        deferredTaxLiabilitiesNonCurrent: Double?,
        otherNonCurrentLiabilities: Double?,
        totalNonCurrentLiabilities: Double?,
        otherLiabilities: Double?,
        capitalLeaseObligations: Double?,
        totalLiabilities: Double?,
        treasuryStock: Double?,
        preferredStock: Double?,
        commonStock: Double?,
        retainedEarnings: Double?,
        additionalPaidInCapital: Double?,
        accumulatedOtherComprehensiveIncomeLoss: Double?,
        otherTotalStockholdersEquity: Double?,
        totalStockholdersEquity: Double?,
        totalEquity: Double?,
        minorityInterest: Double?,
        totalLiabilitiesAndTotalEquity: Double?,
        totalInvestments: Double?,
        totalDebt: Double?,
        netDebt: Double?
    ) {
        self.date = date
        self.symbol = symbol
        self.reportedCurrency = reportedCurrency
        self.cik = cik
        self.filingDate = filingDate
        self.acceptedDate = acceptedDate
        self.fiscalYear = fiscalYear
        self.period = period
        self.cashAndCashEquivalents = cashAndCashEquivalents
        self.shortTermInvestments = shortTermInvestments
        self.cashAndShortTermInvestments = cashAndShortTermInvestments
        self.netReceivables = netReceivables
        self.accountsReceivables = accountsReceivables
        self.otherReceivables = otherReceivables
        self.inventory = inventory
        self.prepaids = prepaids
        self.otherCurrentAssets = otherCurrentAssets
        self.totalCurrentAssets = totalCurrentAssets
        self.propertyPlantEquipmentNet = propertyPlantEquipmentNet
        self.goodwill = goodwill
        self.intangibleAssets = intangibleAssets
        self.goodwillAndIntangibleAssets = goodwillAndIntangibleAssets
        self.longTermInvestments = longTermInvestments
        self.taxAssets = taxAssets
        self.otherNonCurrentAssets = otherNonCurrentAssets
        self.totalNonCurrentAssets = totalNonCurrentAssets
        self.otherAssets = otherAssets
        self.totalAssets = totalAssets
        self.totalPayables = totalPayables
        self.accountPayables = accountPayables
        self.otherPayables = otherPayables
        self.accruedExpenses = accruedExpenses
        self.shortTermDebt = shortTermDebt
        self.capitalLeaseOblationsCurrent = capitalLeaseOblationsCurrent
        self.taxPayables = taxPayables
        self.deferredRevenue = deferredRevenue
        self.otherCurrentLiabilities = otherCurrentLiabilities
        self.totalCurrentLiabilities = totalCurrentLiabilities
        self.longTermDebt = longTermDebt
        self.deferredRevenueNonCurrent = deferredRevenueNonCurrent
        self.deferredTaxLiabilitiesNonCurrent = deferredTaxLiabilitiesNonCurrent
        self.otherNonCurrentLiabilities = otherNonCurrentLiabilities
        self.totalNonCurrentLiabilities = totalNonCurrentLiabilities
        self.otherLiabilities = otherLiabilities
        self.capitalLeaseObligations = capitalLeaseObligations
        self.totalLiabilities = totalLiabilities
        self.treasuryStock = treasuryStock
        self.preferredStock = preferredStock
        self.commonStock = commonStock
        self.retainedEarnings = retainedEarnings
        self.additionalPaidInCapital = additionalPaidInCapital
        self.accumulatedOtherComprehensiveIncomeLoss = accumulatedOtherComprehensiveIncomeLoss
        self.otherTotalStockholdersEquity = otherTotalStockholdersEquity
        self.totalStockholdersEquity = totalStockholdersEquity
        self.totalEquity = totalEquity
        self.minorityInterest = minorityInterest
        self.totalLiabilitiesAndTotalEquity = totalLiabilitiesAndTotalEquity
        self.totalInvestments = totalInvestments
        self.totalDebt = totalDebt
        self.netDebt = netDebt
    }
}

public struct IncomeStatementResponse: Codable, Sendable, Equatable {
    public let date: String
    public let symbol: String
    public let reportedCurrency: String?
    public let cik: String?
    public let filingDate: String?
    public let acceptedDate: String?
    public let fiscalYear: String?
    public let period: String?
    public let revenue: Double?
    public let costOfRevenue: Double?
    public let grossProfit: Double?
    public let researchAndDevelopmentExpenses: Double?
    public let generalAndAdministrativeExpenses: Double?
    public let sellingAndMarketingExpenses: Double?
    public let sellingGeneralAndAdministrativeExpenses: Double?
    public let otherExpenses: Double?
    public let operatingExpenses: Double?
    public let costAndExpenses: Double?
    public let netInterestIncome: Double?
    public let interestIncome: Double?
    public let interestExpense: Double?
    public let depreciationAndAmortization: Double?
    public let ebitda: Double?
    public let ebit: Double?
    public let nonOperatingIncomeExcludingInterest: Double?
    public let operatingIncome: Double?
    public let totalOtherIncomeExpensesNet: Double?
    public let incomeBeforeTax: Double?
    public let incomeTaxExpense: Double?
    public let netIncomeFromContinuingOperations: Double?
    public let netIncomeFromDiscontinuedOperations: Double?
    public let otherAdjustmentsToNetIncome: Double?
    public let netIncome: Double?
    public let netIncomeDeductions: Double?
    public let bottomLineNetIncome: Double?
    public let eps: Double?
    public let epsDiluted: Double?
    public let weightedAverageShsOut: Double?
    public let weightedAverageShsOutDil: Double?

    public init(
        date: String,
        symbol: String,
        reportedCurrency: String?,
        cik: String?,
        filingDate: String?,
        acceptedDate: String?,
        fiscalYear: String?,
        period: String?,
        revenue: Double?,
        costOfRevenue: Double?,
        grossProfit: Double?,
        researchAndDevelopmentExpenses: Double?,
        generalAndAdministrativeExpenses: Double?,
        sellingAndMarketingExpenses: Double?,
        sellingGeneralAndAdministrativeExpenses: Double?,
        otherExpenses: Double?,
        operatingExpenses: Double?,
        costAndExpenses: Double?,
        netInterestIncome: Double?,
        interestIncome: Double?,
        interestExpense: Double?,
        depreciationAndAmortization: Double?,
        ebitda: Double?,
        ebit: Double?,
        nonOperatingIncomeExcludingInterest: Double?,
        operatingIncome: Double?,
        totalOtherIncomeExpensesNet: Double?,
        incomeBeforeTax: Double?,
        incomeTaxExpense: Double?,
        netIncomeFromContinuingOperations: Double?,
        netIncomeFromDiscontinuedOperations: Double?,
        otherAdjustmentsToNetIncome: Double?,
        netIncome: Double?,
        netIncomeDeductions: Double?,
        bottomLineNetIncome: Double?,
        eps: Double?,
        epsDiluted: Double?,
        weightedAverageShsOut: Double?,
        weightedAverageShsOutDil: Double?
    ) {
        self.date = date
        self.symbol = symbol
        self.reportedCurrency = reportedCurrency
        self.cik = cik
        self.filingDate = filingDate
        self.acceptedDate = acceptedDate
        self.fiscalYear = fiscalYear
        self.period = period
        self.revenue = revenue
        self.costOfRevenue = costOfRevenue
        self.grossProfit = grossProfit
        self.researchAndDevelopmentExpenses = researchAndDevelopmentExpenses
        self.generalAndAdministrativeExpenses = generalAndAdministrativeExpenses
        self.sellingAndMarketingExpenses = sellingAndMarketingExpenses
        self.sellingGeneralAndAdministrativeExpenses = sellingGeneralAndAdministrativeExpenses
        self.otherExpenses = otherExpenses
        self.operatingExpenses = operatingExpenses
        self.costAndExpenses = costAndExpenses
        self.netInterestIncome = netInterestIncome
        self.interestIncome = interestIncome
        self.interestExpense = interestExpense
        self.depreciationAndAmortization = depreciationAndAmortization
        self.ebitda = ebitda
        self.ebit = ebit
        self.nonOperatingIncomeExcludingInterest = nonOperatingIncomeExcludingInterest
        self.operatingIncome = operatingIncome
        self.totalOtherIncomeExpensesNet = totalOtherIncomeExpensesNet
        self.incomeBeforeTax = incomeBeforeTax
        self.incomeTaxExpense = incomeTaxExpense
        self.netIncomeFromContinuingOperations = netIncomeFromContinuingOperations
        self.netIncomeFromDiscontinuedOperations = netIncomeFromDiscontinuedOperations
        self.otherAdjustmentsToNetIncome = otherAdjustmentsToNetIncome
        self.netIncome = netIncome
        self.netIncomeDeductions = netIncomeDeductions
        self.bottomLineNetIncome = bottomLineNetIncome
        self.eps = eps
        self.epsDiluted = epsDiluted
        self.weightedAverageShsOut = weightedAverageShsOut
        self.weightedAverageShsOutDil = weightedAverageShsOutDil
    }
}

public struct CashFlowStatementResponse: Codable, Sendable, Equatable {
    public let date: String
    public let symbol: String
    public let reportedCurrency: String?
    public let cik: String?
    public let filingDate: String?
    public let acceptedDate: String?
    public let fiscalYear: String?
    public let period: String?
    public let netIncome: Double?
    public let depreciationAndAmortization: Double?
    public let deferredIncomeTax: Double?
    public let stockBasedCompensation: Double?
    public let changeInWorkingCapital: Double?
    public let accountsReceivables: Double?
    public let inventory: Double?
    public let accountsPayables: Double?
    public let otherWorkingCapital: Double?
    public let otherNonCashItems: Double?
    public let netCashProvidedByOperatingActivities: Double?
    public let investmentsInPropertyPlantAndEquipment: Double?
    public let acquisitionsNet: Double?
    public let purchasesOfInvestments: Double?
    public let salesMaturitiesOfInvestments: Double?
    public let otherInvestingActivities: Double?
    public let netCashProvidedByInvestingActivities: Double?
    public let netDebtIssuance: Double?
    public let longTermNetDebtIssuance: Double?
    public let shortTermNetDebtIssuance: Double?
    public let netStockIssuance: Double?
    public let netCommonStockIssuance: Double?
    public let commonStockIssuance: Double?
    public let commonStockRepurchased: Double?
    public let netPreferredStockIssuance: Double?
    public let netDividendsPaid: Double?
    public let commonDividendsPaid: Double?
    public let preferredDividendsPaid: Double?
    public let otherFinancingActivities: Double?
    public let netCashProvidedByFinancingActivities: Double?
    public let effectOfForexChangesOnCash: Double?
    public let netChangeInCash: Double?
    public let cashAtEndOfPeriod: Double?
    public let cashAtBeginningOfPeriod: Double?
    public let operatingCashFlow: Double?
    public let capitalExpenditure: Double?
    public let freeCashFlow: Double?
    public let incomeTaxesPaid: Double?
    public let interestPaid: Double?

    public init(
        date: String,
        symbol: String,
        reportedCurrency: String?,
        cik: String?,
        filingDate: String?,
        acceptedDate: String?,
        fiscalYear: String?,
        period: String?,
        netIncome: Double?,
        depreciationAndAmortization: Double?,
        deferredIncomeTax: Double?,
        stockBasedCompensation: Double?,
        changeInWorkingCapital: Double?,
        accountsReceivables: Double?,
        inventory: Double?,
        accountsPayables: Double?,
        otherWorkingCapital: Double?,
        otherNonCashItems: Double?,
        netCashProvidedByOperatingActivities: Double?,
        investmentsInPropertyPlantAndEquipment: Double?,
        acquisitionsNet: Double?,
        purchasesOfInvestments: Double?,
        salesMaturitiesOfInvestments: Double?,
        otherInvestingActivities: Double?,
        netCashProvidedByInvestingActivities: Double?,
        netDebtIssuance: Double?,
        longTermNetDebtIssuance: Double?,
        shortTermNetDebtIssuance: Double?,
        netStockIssuance: Double?,
        netCommonStockIssuance: Double?,
        commonStockIssuance: Double?,
        commonStockRepurchased: Double?,
        netPreferredStockIssuance: Double?,
        netDividendsPaid: Double?,
        commonDividendsPaid: Double?,
        preferredDividendsPaid: Double?,
        otherFinancingActivities: Double?,
        netCashProvidedByFinancingActivities: Double?,
        effectOfForexChangesOnCash: Double?,
        netChangeInCash: Double?,
        cashAtEndOfPeriod: Double?,
        cashAtBeginningOfPeriod: Double?,
        operatingCashFlow: Double?,
        capitalExpenditure: Double?,
        freeCashFlow: Double?,
        incomeTaxesPaid: Double?,
        interestPaid: Double?
    ) {
        self.date = date
        self.symbol = symbol
        self.reportedCurrency = reportedCurrency
        self.cik = cik
        self.filingDate = filingDate
        self.acceptedDate = acceptedDate
        self.fiscalYear = fiscalYear
        self.period = period
        self.netIncome = netIncome
        self.depreciationAndAmortization = depreciationAndAmortization
        self.deferredIncomeTax = deferredIncomeTax
        self.stockBasedCompensation = stockBasedCompensation
        self.changeInWorkingCapital = changeInWorkingCapital
        self.accountsReceivables = accountsReceivables
        self.inventory = inventory
        self.accountsPayables = accountsPayables
        self.otherWorkingCapital = otherWorkingCapital
        self.otherNonCashItems = otherNonCashItems
        self.netCashProvidedByOperatingActivities = netCashProvidedByOperatingActivities
        self.investmentsInPropertyPlantAndEquipment = investmentsInPropertyPlantAndEquipment
        self.acquisitionsNet = acquisitionsNet
        self.purchasesOfInvestments = purchasesOfInvestments
        self.salesMaturitiesOfInvestments = salesMaturitiesOfInvestments
        self.otherInvestingActivities = otherInvestingActivities
        self.netCashProvidedByInvestingActivities = netCashProvidedByInvestingActivities
        self.netDebtIssuance = netDebtIssuance
        self.longTermNetDebtIssuance = longTermNetDebtIssuance
        self.shortTermNetDebtIssuance = shortTermNetDebtIssuance
        self.netStockIssuance = netStockIssuance
        self.netCommonStockIssuance = netCommonStockIssuance
        self.commonStockIssuance = commonStockIssuance
        self.commonStockRepurchased = commonStockRepurchased
        self.netPreferredStockIssuance = netPreferredStockIssuance
        self.netDividendsPaid = netDividendsPaid
        self.commonDividendsPaid = commonDividendsPaid
        self.preferredDividendsPaid = preferredDividendsPaid
        self.otherFinancingActivities = otherFinancingActivities
        self.netCashProvidedByFinancingActivities = netCashProvidedByFinancingActivities
        self.effectOfForexChangesOnCash = effectOfForexChangesOnCash
        self.netChangeInCash = netChangeInCash
        self.cashAtEndOfPeriod = cashAtEndOfPeriod
        self.cashAtBeginningOfPeriod = cashAtBeginningOfPeriod
        self.operatingCashFlow = operatingCashFlow
        self.capitalExpenditure = capitalExpenditure
        self.freeCashFlow = freeCashFlow
        self.incomeTaxesPaid = incomeTaxesPaid
        self.interestPaid = interestPaid
    }
}

public struct FinancialGrowthResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let date: String
    public let fiscalYear: String?
    public let period: String?
    public let reportedCurrency: String?
    public let revenueGrowth: Double?
    public let grossProfitGrowth: Double?
    public let ebitgrowth: Double?
    public let operatingIncomeGrowth: Double?
    public let netIncomeGrowth: Double?
    public let epsgrowth: Double?
    public let epsdilutedGrowth: Double?
    public let weightedAverageSharesGrowth: Double?
    public let weightedAverageSharesDilutedGrowth: Double?
    public let dividendsPerShareGrowth: Double?
    public let operatingCashFlowGrowth: Double?
    public let receivablesGrowth: Double?
    public let inventoryGrowth: Double?
    public let assetGrowth: Double?
    public let bookValueperShareGrowth: Double?
    public let debtGrowth: Double?
    public let rdexpenseGrowth: Double?
    public let sgaexpensesGrowth: Double?
    public let freeCashFlowGrowth: Double?
    public let tenYRevenueGrowthPerShare: Double?
    public let fiveYRevenueGrowthPerShare: Double?
    public let threeYRevenueGrowthPerShare: Double?
    public let tenYOperatingCFGrowthPerShare: Double?
    public let fiveYOperatingCFGrowthPerShare: Double?
    public let threeYOperatingCFGrowthPerShare: Double?
    public let tenYNetIncomeGrowthPerShare: Double?
    public let fiveYNetIncomeGrowthPerShare: Double?
    public let threeYNetIncomeGrowthPerShare: Double?
    public let tenYShareholdersEquityGrowthPerShare: Double?
    public let fiveYShareholdersEquityGrowthPerShare: Double?
    public let threeYShareholdersEquityGrowthPerShare: Double?
    public let tenYDividendperShareGrowthPerShare: Double?
    public let fiveYDividendperShareGrowthPerShare: Double?
    public let threeYDividendperShareGrowthPerShare: Double?
    public let ebitdaGrowth: Double?
    public let growthCapitalExpenditure: Double?
    public let tenYBottomLineNetIncomeGrowthPerShare: Double?
    public let fiveYBottomLineNetIncomeGrowthPerShare: Double?
    public let threeYBottomLineNetIncomeGrowthPerShare: Double?

    public init(
        symbol: String,
        date: String,
        fiscalYear: String?,
        period: String?,
        reportedCurrency: String?,
        revenueGrowth: Double?,
        grossProfitGrowth: Double?,
        ebitgrowth: Double?,
        operatingIncomeGrowth: Double?,
        netIncomeGrowth: Double?,
        epsgrowth: Double?,
        epsdilutedGrowth: Double?,
        weightedAverageSharesGrowth: Double?,
        weightedAverageSharesDilutedGrowth: Double?,
        dividendsPerShareGrowth: Double?,
        operatingCashFlowGrowth: Double?,
        receivablesGrowth: Double?,
        inventoryGrowth: Double?,
        assetGrowth: Double?,
        bookValueperShareGrowth: Double?,
        debtGrowth: Double?,
        rdexpenseGrowth: Double?,
        sgaexpensesGrowth: Double?,
        freeCashFlowGrowth: Double?,
        tenYRevenueGrowthPerShare: Double?,
        fiveYRevenueGrowthPerShare: Double?,
        threeYRevenueGrowthPerShare: Double?,
        tenYOperatingCFGrowthPerShare: Double?,
        fiveYOperatingCFGrowthPerShare: Double?,
        threeYOperatingCFGrowthPerShare: Double?,
        tenYNetIncomeGrowthPerShare: Double?,
        fiveYNetIncomeGrowthPerShare: Double?,
        threeYNetIncomeGrowthPerShare: Double?,
        tenYShareholdersEquityGrowthPerShare: Double?,
        fiveYShareholdersEquityGrowthPerShare: Double?,
        threeYShareholdersEquityGrowthPerShare: Double?,
        tenYDividendperShareGrowthPerShare: Double?,
        fiveYDividendperShareGrowthPerShare: Double?,
        threeYDividendperShareGrowthPerShare: Double?,
        ebitdaGrowth: Double?,
        growthCapitalExpenditure: Double?,
        tenYBottomLineNetIncomeGrowthPerShare: Double?,
        fiveYBottomLineNetIncomeGrowthPerShare: Double?,
        threeYBottomLineNetIncomeGrowthPerShare: Double?
    ) {
        self.symbol = symbol
        self.date = date
        self.fiscalYear = fiscalYear
        self.period = period
        self.reportedCurrency = reportedCurrency
        self.revenueGrowth = revenueGrowth
        self.grossProfitGrowth = grossProfitGrowth
        self.ebitgrowth = ebitgrowth
        self.operatingIncomeGrowth = operatingIncomeGrowth
        self.netIncomeGrowth = netIncomeGrowth
        self.epsgrowth = epsgrowth
        self.epsdilutedGrowth = epsdilutedGrowth
        self.weightedAverageSharesGrowth = weightedAverageSharesGrowth
        self.weightedAverageSharesDilutedGrowth = weightedAverageSharesDilutedGrowth
        self.dividendsPerShareGrowth = dividendsPerShareGrowth
        self.operatingCashFlowGrowth = operatingCashFlowGrowth
        self.receivablesGrowth = receivablesGrowth
        self.inventoryGrowth = inventoryGrowth
        self.assetGrowth = assetGrowth
        self.bookValueperShareGrowth = bookValueperShareGrowth
        self.debtGrowth = debtGrowth
        self.rdexpenseGrowth = rdexpenseGrowth
        self.sgaexpensesGrowth = sgaexpensesGrowth
        self.freeCashFlowGrowth = freeCashFlowGrowth
        self.tenYRevenueGrowthPerShare = tenYRevenueGrowthPerShare
        self.fiveYRevenueGrowthPerShare = fiveYRevenueGrowthPerShare
        self.threeYRevenueGrowthPerShare = threeYRevenueGrowthPerShare
        self.tenYOperatingCFGrowthPerShare = tenYOperatingCFGrowthPerShare
        self.fiveYOperatingCFGrowthPerShare = fiveYOperatingCFGrowthPerShare
        self.threeYOperatingCFGrowthPerShare = threeYOperatingCFGrowthPerShare
        self.tenYNetIncomeGrowthPerShare = tenYNetIncomeGrowthPerShare
        self.fiveYNetIncomeGrowthPerShare = fiveYNetIncomeGrowthPerShare
        self.threeYNetIncomeGrowthPerShare = threeYNetIncomeGrowthPerShare
        self.tenYShareholdersEquityGrowthPerShare = tenYShareholdersEquityGrowthPerShare
        self.fiveYShareholdersEquityGrowthPerShare = fiveYShareholdersEquityGrowthPerShare
        self.threeYShareholdersEquityGrowthPerShare = threeYShareholdersEquityGrowthPerShare
        self.tenYDividendperShareGrowthPerShare = tenYDividendperShareGrowthPerShare
        self.fiveYDividendperShareGrowthPerShare = fiveYDividendperShareGrowthPerShare
        self.threeYDividendperShareGrowthPerShare = threeYDividendperShareGrowthPerShare
        self.ebitdaGrowth = ebitdaGrowth
        self.growthCapitalExpenditure = growthCapitalExpenditure
        self.tenYBottomLineNetIncomeGrowthPerShare = tenYBottomLineNetIncomeGrowthPerShare
        self.fiveYBottomLineNetIncomeGrowthPerShare = fiveYBottomLineNetIncomeGrowthPerShare
        self.threeYBottomLineNetIncomeGrowthPerShare = threeYBottomLineNetIncomeGrowthPerShare
    }
}

public struct AnalystEstimatesResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let date: String
    public let revenueLow: Double?
    public let revenueHigh: Double?
    public let revenueAvg: Double?
    public let ebitdaLow: Double?
    public let ebitdaHigh: Double?
    public let ebitdaAvg: Double?
    public let ebitLow: Double?
    public let ebitHigh: Double?
    public let ebitAvg: Double?
    public let netIncomeLow: Double?
    public let netIncomeHigh: Double?
    public let netIncomeAvg: Double?
    public let sgaExpenseLow: Double?
    public let sgaExpenseHigh: Double?
    public let sgaExpenseAvg: Double?
    public let epsAvg: Double?
    public let epsHigh: Double?
    public let epsLow: Double?
    public let numAnalystsRevenue: Int?
    public let numAnalystsEps: Int?

    public init(
        symbol: String,
        date: String,
        revenueLow: Double?,
        revenueHigh: Double?,
        revenueAvg: Double?,
        ebitdaLow: Double?,
        ebitdaHigh: Double?,
        ebitdaAvg: Double?,
        ebitLow: Double?,
        ebitHigh: Double?,
        ebitAvg: Double?,
        netIncomeLow: Double?,
        netIncomeHigh: Double?,
        netIncomeAvg: Double?,
        sgaExpenseLow: Double?,
        sgaExpenseHigh: Double?,
        sgaExpenseAvg: Double?,
        epsAvg: Double?,
        epsHigh: Double?,
        epsLow: Double?,
        numAnalystsRevenue: Int?,
        numAnalystsEps: Int?
    ) {
        self.symbol = symbol
        self.date = date
        self.revenueLow = revenueLow
        self.revenueHigh = revenueHigh
        self.revenueAvg = revenueAvg
        self.ebitdaLow = ebitdaLow
        self.ebitdaHigh = ebitdaHigh
        self.ebitdaAvg = ebitdaAvg
        self.ebitLow = ebitLow
        self.ebitHigh = ebitHigh
        self.ebitAvg = ebitAvg
        self.netIncomeLow = netIncomeLow
        self.netIncomeHigh = netIncomeHigh
        self.netIncomeAvg = netIncomeAvg
        self.sgaExpenseLow = sgaExpenseLow
        self.sgaExpenseHigh = sgaExpenseHigh
        self.sgaExpenseAvg = sgaExpenseAvg
        self.epsAvg = epsAvg
        self.epsHigh = epsHigh
        self.epsLow = epsLow
        self.numAnalystsRevenue = numAnalystsRevenue
        self.numAnalystsEps = numAnalystsEps
    }
}

public struct RatiosResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let date: String
    public let fiscalYear: String?
    public let period: String?
    public let reportedCurrency: String?
    public let grossProfitMargin: Double?
    public let ebitMargin: Double?
    public let ebitdaMargin: Double?
    public let operatingProfitMargin: Double?
    public let pretaxProfitMargin: Double?
    public let continuousOperationsProfitMargin: Double?
    public let netProfitMargin: Double?
    public let bottomLineProfitMargin: Double?
    public let receivablesTurnover: Double?
    public let payablesTurnover: Double?
    public let inventoryTurnover: Double?
    public let fixedAssetTurnover: Double?
    public let assetTurnover: Double?
    public let currentRatio: Double?
    public let quickRatio: Double?
    public let solvencyRatio: Double?
    public let cashRatio: Double?
    public let priceToEarningsRatio: Double?
    public let priceToEarningsGrowthRatio: Double?
    public let forwardPriceToEarningsGrowthRatio: Double?
    public let priceToBookRatio: Double?
    public let priceToSalesRatio: Double?
    public let priceToFreeCashFlowRatio: Double?
    public let priceToOperatingCashFlowRatio: Double?
    public let debtToAssetsRatio: Double?
    public let debtToEquityRatio: Double?
    public let debtToCapitalRatio: Double?
    public let longTermDebtToCapitalRatio: Double?
    public let financialLeverageRatio: Double?
    public let workingCapitalTurnoverRatio: Double?
    public let operatingCashFlowRatio: Double?
    public let operatingCashFlowSalesRatio: Double?
    public let freeCashFlowOperatingCashFlowRatio: Double?
    public let debtServiceCoverageRatio: Double?
    public let interestCoverageRatio: Double?
    public let shortTermOperatingCashFlowCoverageRatio: Double?
    public let operatingCashFlowCoverageRatio: Double?
    public let capitalExpenditureCoverageRatio: Double?
    public let dividendPaidAndCapexCoverageRatio: Double?
    public let dividendPayoutRatio: Double?
    public let dividendYield: Double?
    public let dividendYieldPercentage: Double?
    public let revenuePerShare: Double?
    public let netIncomePerShare: Double?
    public let interestDebtPerShare: Double?
    public let cashPerShare: Double?
    public let bookValuePerShare: Double?
    public let tangibleBookValuePerShare: Double?
    public let shareholdersEquityPerShare: Double?
    public let operatingCashFlowPerShare: Double?
    public let capexPerShare: Double?
    public let freeCashFlowPerShare: Double?
    public let netIncomePerEBT: Double?
    public let ebtPerEbit: Double?
    public let priceToFairValue: Double?
    public let debtToMarketCap: Double?
    public let effectiveTaxRate: Double?
    public let enterpriseValueMultiple: Double?

    public init(
        symbol: String,
        date: String,
        fiscalYear: String?,
        period: String?,
        reportedCurrency: String?,
        grossProfitMargin: Double?,
        ebitMargin: Double?,
        ebitdaMargin: Double?,
        operatingProfitMargin: Double?,
        pretaxProfitMargin: Double?,
        continuousOperationsProfitMargin: Double?,
        netProfitMargin: Double?,
        bottomLineProfitMargin: Double?,
        receivablesTurnover: Double?,
        payablesTurnover: Double?,
        inventoryTurnover: Double?,
        fixedAssetTurnover: Double?,
        assetTurnover: Double?,
        currentRatio: Double?,
        quickRatio: Double?,
        solvencyRatio: Double?,
        cashRatio: Double?,
        priceToEarningsRatio: Double?,
        priceToEarningsGrowthRatio: Double?,
        forwardPriceToEarningsGrowthRatio: Double?,
        priceToBookRatio: Double?,
        priceToSalesRatio: Double?,
        priceToFreeCashFlowRatio: Double?,
        priceToOperatingCashFlowRatio: Double?,
        debtToAssetsRatio: Double?,
        debtToEquityRatio: Double?,
        debtToCapitalRatio: Double?,
        longTermDebtToCapitalRatio: Double?,
        financialLeverageRatio: Double?,
        workingCapitalTurnoverRatio: Double?,
        operatingCashFlowRatio: Double?,
        operatingCashFlowSalesRatio: Double?,
        freeCashFlowOperatingCashFlowRatio: Double?,
        debtServiceCoverageRatio: Double?,
        interestCoverageRatio: Double?,
        shortTermOperatingCashFlowCoverageRatio: Double?,
        operatingCashFlowCoverageRatio: Double?,
        capitalExpenditureCoverageRatio: Double?,
        dividendPaidAndCapexCoverageRatio: Double?,
        dividendPayoutRatio: Double?,
        dividendYield: Double?,
        dividendYieldPercentage: Double?,
        revenuePerShare: Double?,
        netIncomePerShare: Double?,
        interestDebtPerShare: Double?,
        cashPerShare: Double?,
        bookValuePerShare: Double?,
        tangibleBookValuePerShare: Double?,
        shareholdersEquityPerShare: Double?,
        operatingCashFlowPerShare: Double?,
        capexPerShare: Double?,
        freeCashFlowPerShare: Double?,
        netIncomePerEBT: Double?,
        ebtPerEbit: Double?,
        priceToFairValue: Double?,
        debtToMarketCap: Double?,
        effectiveTaxRate: Double?,
        enterpriseValueMultiple: Double?
    ) {
        self.symbol = symbol
        self.date = date
        self.fiscalYear = fiscalYear
        self.period = period
        self.reportedCurrency = reportedCurrency
        self.grossProfitMargin = grossProfitMargin
        self.ebitMargin = ebitMargin
        self.ebitdaMargin = ebitdaMargin
        self.operatingProfitMargin = operatingProfitMargin
        self.pretaxProfitMargin = pretaxProfitMargin
        self.continuousOperationsProfitMargin = continuousOperationsProfitMargin
        self.netProfitMargin = netProfitMargin
        self.bottomLineProfitMargin = bottomLineProfitMargin
        self.receivablesTurnover = receivablesTurnover
        self.payablesTurnover = payablesTurnover
        self.inventoryTurnover = inventoryTurnover
        self.fixedAssetTurnover = fixedAssetTurnover
        self.assetTurnover = assetTurnover
        self.currentRatio = currentRatio
        self.quickRatio = quickRatio
        self.solvencyRatio = solvencyRatio
        self.cashRatio = cashRatio
        self.priceToEarningsRatio = priceToEarningsRatio
        self.priceToEarningsGrowthRatio = priceToEarningsGrowthRatio
        self.forwardPriceToEarningsGrowthRatio = forwardPriceToEarningsGrowthRatio
        self.priceToBookRatio = priceToBookRatio
        self.priceToSalesRatio = priceToSalesRatio
        self.priceToFreeCashFlowRatio = priceToFreeCashFlowRatio
        self.priceToOperatingCashFlowRatio = priceToOperatingCashFlowRatio
        self.debtToAssetsRatio = debtToAssetsRatio
        self.debtToEquityRatio = debtToEquityRatio
        self.debtToCapitalRatio = debtToCapitalRatio
        self.longTermDebtToCapitalRatio = longTermDebtToCapitalRatio
        self.financialLeverageRatio = financialLeverageRatio
        self.workingCapitalTurnoverRatio = workingCapitalTurnoverRatio
        self.operatingCashFlowRatio = operatingCashFlowRatio
        self.operatingCashFlowSalesRatio = operatingCashFlowSalesRatio
        self.freeCashFlowOperatingCashFlowRatio = freeCashFlowOperatingCashFlowRatio
        self.debtServiceCoverageRatio = debtServiceCoverageRatio
        self.interestCoverageRatio = interestCoverageRatio
        self.shortTermOperatingCashFlowCoverageRatio = shortTermOperatingCashFlowCoverageRatio
        self.operatingCashFlowCoverageRatio = operatingCashFlowCoverageRatio
        self.capitalExpenditureCoverageRatio = capitalExpenditureCoverageRatio
        self.dividendPaidAndCapexCoverageRatio = dividendPaidAndCapexCoverageRatio
        self.dividendPayoutRatio = dividendPayoutRatio
        self.dividendYield = dividendYield
        self.dividendYieldPercentage = dividendYieldPercentage
        self.revenuePerShare = revenuePerShare
        self.netIncomePerShare = netIncomePerShare
        self.interestDebtPerShare = interestDebtPerShare
        self.cashPerShare = cashPerShare
        self.bookValuePerShare = bookValuePerShare
        self.tangibleBookValuePerShare = tangibleBookValuePerShare
        self.shareholdersEquityPerShare = shareholdersEquityPerShare
        self.operatingCashFlowPerShare = operatingCashFlowPerShare
        self.capexPerShare = capexPerShare
        self.freeCashFlowPerShare = freeCashFlowPerShare
        self.netIncomePerEBT = netIncomePerEBT
        self.ebtPerEbit = ebtPerEbit
        self.priceToFairValue = priceToFairValue
        self.debtToMarketCap = debtToMarketCap
        self.effectiveTaxRate = effectiveTaxRate
        self.enterpriseValueMultiple = enterpriseValueMultiple
    }
}
