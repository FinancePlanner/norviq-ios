import Foundation

public enum ChartMetricGroup: String, Codable, CaseIterable, Sendable {
    case incomeStatement
    case balanceSheet
    case cashFlow
    case ratios
    case growth
    case derived

    public var title: String {
        switch self {
        case .incomeStatement: return "Income Statement"
        case .balanceSheet: return "Balance Sheet"
        case .cashFlow: return "Cash Flow"
        case .ratios: return "Ratios"
        case .growth: return "Growth"
        case .derived: return "Derived Metrics"
        }
    }
}

/// How a metric behaves when assembled into a trailing-twelve-month series.
public enum ChartMetricAggregation: String, Codable, Sendable {
    /// TTM value = rolling sum of 4 consecutive quarters (revenue, net income, cash flows).
    case flow
    /// TTM value = latest quarter's value (all balance-sheet items, share counts).
    case pointInTime
    /// Not summable; only supported for TTM when recomputable from flow components (margins).
    case ratio
}

public enum ChartMetricFormat: String, Codable, Sendable {
    case currency
    case percent
    case ratio
    case perShare
    case shares
}

public struct ChartMetricDescriptor: Codable, Sendable, Equatable, Identifiable {
    public let key: String
    public let label: String
    public let group: ChartMetricGroup
    public let format: ChartMetricFormat
    public let aggregation: ChartMetricAggregation
    public let supportsTTM: Bool

    public var id: String {
        key
    }

    public init(
        key: String,
        label: String,
        group: ChartMetricGroup,
        format: ChartMetricFormat,
        aggregation: ChartMetricAggregation,
        supportsTTM: Bool
    ) {
        self.key = key
        self.label = label
        self.group = group
        self.format = format
        self.aggregation = aggregation
        self.supportsTTM = supportsTTM
    }
}

/// Single source of truth for every metric the chart builder can plot.
///
/// Keys match the corresponding DTO property name except where the same
/// property name appears on more than one statement; those collisions are
/// resolved with statement-specific keys (e.g. `changeInInventory` for the
/// cash-flow working-capital delta vs `inventory` on the balance sheet).
public enum ChartBuilderMetricCatalog {
    public static let all: [ChartMetricDescriptor] = buildCatalog()

    public static let byKey: [String: ChartMetricDescriptor] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.key, $0) }
    )

    public static func metrics(in group: ChartMetricGroup) -> [ChartMetricDescriptor] {
        all.filter { $0.group == group }
    }

    // MARK: - Catalog definition

    // swiftlint:disable:next function_body_length — one flat catalogue literal.
    private static func buildCatalog() -> [ChartMetricDescriptor] {
        var metrics: [ChartMetricDescriptor] = []

        func add(
            _ key: String,
            _ group: ChartMetricGroup,
            _ format: ChartMetricFormat,
            _ aggregation: ChartMetricAggregation,
            ttm: Bool? = nil,
            label: String? = nil
        ) {
            let supportsTTM = ttm ?? (aggregation != .ratio)
            metrics.append(
                ChartMetricDescriptor(
                    key: key,
                    label: label ?? Self.label(for: key),
                    group: group,
                    format: format,
                    aggregation: aggregation,
                    supportsTTM: supportsTTM
                )
            )
        }

        // MARK: Income statement (source: IncomeStatementResponse)

        for key in [
            "revenue", "costOfRevenue", "grossProfit",
            "researchAndDevelopmentExpenses", "generalAndAdministrativeExpenses",
            "sellingAndMarketingExpenses", "sellingGeneralAndAdministrativeExpenses",
            "otherExpenses", "operatingExpenses", "costAndExpenses",
            "netInterestIncome", "interestIncome", "interestExpense",
            "ebitda", "ebit", "nonOperatingIncomeExcludingInterest",
            "operatingIncome", "totalOtherIncomeExpensesNet",
            "incomeBeforeTax", "incomeTaxExpense",
            "netIncomeFromContinuingOperations", "netIncomeFromDiscontinuedOperations",
            "otherAdjustmentsToNetIncome", "netIncome", "netIncomeDeductions",
            "bottomLineNetIncome",
        ] {
            add(key, .incomeStatement, .currency, .flow)
        }
        add("eps", .incomeStatement, .perShare, .flow)
        add("epsDiluted", .incomeStatement, .perShare, .flow)
        add("weightedAverageShsOut", .incomeStatement, .shares, .pointInTime)
        add("weightedAverageShsOutDil", .incomeStatement, .shares, .pointInTime)

        // MARK: Balance sheet (source: BalanceSheetStatementResponse) — all point-in-time

        for key in [
            "cashAndCashEquivalents", "shortTermInvestments", "cashAndShortTermInvestments",
            "netReceivables", "accountsReceivables", "otherReceivables",
            "inventory", "prepaids", "otherCurrentAssets", "totalCurrentAssets",
            "propertyPlantEquipmentNet", "goodwill", "intangibleAssets",
            "goodwillAndIntangibleAssets", "longTermInvestments", "taxAssets",
            "otherNonCurrentAssets", "totalNonCurrentAssets", "otherAssets", "totalAssets",
            "totalPayables", "accountPayables", "otherPayables", "accruedExpenses",
            "shortTermDebt", "capitalLeaseOblationsCurrent", "taxPayables",
            "deferredRevenue", "otherCurrentLiabilities", "totalCurrentLiabilities",
            "longTermDebt", "deferredRevenueNonCurrent", "deferredTaxLiabilitiesNonCurrent",
            "otherNonCurrentLiabilities", "totalNonCurrentLiabilities", "otherLiabilities",
            "capitalLeaseObligations", "totalLiabilities",
            "treasuryStock", "preferredStock", "commonStock", "retainedEarnings",
            "additionalPaidInCapital", "accumulatedOtherComprehensiveIncomeLoss",
            "otherTotalStockholdersEquity", "totalStockholdersEquity", "totalEquity",
            "minorityInterest", "totalLiabilitiesAndTotalEquity", "totalInvestments",
            "totalDebt", "netDebt",
        ] {
            add(key, .balanceSheet, .currency, .pointInTime)
        }

        // MARK: Cash flow (source: CashFlowStatementResponse) — all flows.

        // netIncome is served from the income statement; working-capital deltas
        // get `changeIn*` keys to avoid colliding with balance-sheet levels.
        for key in [
            "depreciationAndAmortization", "deferredIncomeTax", "stockBasedCompensation",
            "changeInWorkingCapital", "changeInAccountsReceivables", "changeInInventory",
            "changeInAccountsPayables", "otherWorkingCapital", "otherNonCashItems",
            "netCashProvidedByOperatingActivities",
            "investmentsInPropertyPlantAndEquipment", "acquisitionsNet",
            "purchasesOfInvestments", "salesMaturitiesOfInvestments",
            "otherInvestingActivities", "netCashProvidedByInvestingActivities",
            "netDebtIssuance", "longTermNetDebtIssuance", "shortTermNetDebtIssuance",
            "netStockIssuance", "netCommonStockIssuance", "commonStockIssuance",
            "commonStockRepurchased", "netPreferredStockIssuance",
            "netDividendsPaid", "commonDividendsPaid", "preferredDividendsPaid",
            "otherFinancingActivities", "netCashProvidedByFinancingActivities",
            "effectOfForexChangesOnCash", "netChangeInCash",
            "operatingCashFlow", "capitalExpenditure", "freeCashFlow",
            "incomeTaxesPaid", "interestPaid",
        ] {
            add(key, .cashFlow, .currency, .flow)
        }

        // MARK: Ratios (source: RatiosResponse) — point-in-period, not summable.

        // Margins recomputable from TTM income components support TTM.
        let ttmRecomputableMargins: Set = [
            "grossProfitMargin", "ebitMargin", "ebitdaMargin",
            "operatingProfitMargin", "pretaxProfitMargin", "netProfitMargin",
        ]
        for key in [
            "grossProfitMargin", "ebitMargin", "ebitdaMargin", "operatingProfitMargin",
            "pretaxProfitMargin", "continuousOperationsProfitMargin", "netProfitMargin",
            "bottomLineProfitMargin", "dividendPayoutRatio", "dividendYield",
            "effectiveTaxRate",
        ] {
            add(key, .ratios, .percent, .ratio, ttm: ttmRecomputableMargins.contains(key))
        }
        for key in [
            "receivablesTurnover", "payablesTurnover", "inventoryTurnover",
            "fixedAssetTurnover", "assetTurnover", "currentRatio", "quickRatio",
            "solvencyRatio", "cashRatio", "priceToEarningsRatio",
            "priceToEarningsGrowthRatio", "forwardPriceToEarningsGrowthRatio",
            "priceToBookRatio", "priceToSalesRatio", "priceToFreeCashFlowRatio",
            "priceToOperatingCashFlowRatio", "debtToAssetsRatio", "debtToEquityRatio",
            "debtToCapitalRatio", "longTermDebtToCapitalRatio", "financialLeverageRatio",
            "workingCapitalTurnoverRatio", "operatingCashFlowRatio",
            "operatingCashFlowSalesRatio", "freeCashFlowOperatingCashFlowRatio",
            "debtServiceCoverageRatio", "interestCoverageRatio",
            "shortTermOperatingCashFlowCoverageRatio", "operatingCashFlowCoverageRatio",
            "capitalExpenditureCoverageRatio", "dividendPaidAndCapexCoverageRatio",
            "netIncomePerEBT", "ebtPerEbit", "priceToFairValue", "debtToMarketCap",
            "enterpriseValueMultiple",
        ] {
            add(key, .ratios, .ratio, .ratio, ttm: false)
        }
        for key in [
            "revenuePerShare", "netIncomePerShare", "interestDebtPerShare", "cashPerShare",
            "bookValuePerShare", "tangibleBookValuePerShare", "shareholdersEquityPerShare",
            "operatingCashFlowPerShare", "capexPerShare", "freeCashFlowPerShare",
        ] {
            add(key, .ratios, .perShare, .ratio, ttm: false)
        }

        // MARK: Growth (source: FinancialGrowthResponse) — period-over-period percentages.

        for key in [
            "revenueGrowth", "grossProfitGrowth", "ebitgrowth", "operatingIncomeGrowth",
            "netIncomeGrowth", "epsgrowth", "epsdilutedGrowth",
            "weightedAverageSharesGrowth", "weightedAverageSharesDilutedGrowth",
            "dividendsPerShareGrowth", "operatingCashFlowGrowth", "receivablesGrowth",
            "inventoryGrowth", "assetGrowth", "bookValueperShareGrowth", "debtGrowth",
            "rdexpenseGrowth", "sgaexpensesGrowth", "freeCashFlowGrowth", "ebitdaGrowth",
            "growthCapitalExpenditure",
            "tenYRevenueGrowthPerShare", "fiveYRevenueGrowthPerShare",
            "threeYRevenueGrowthPerShare",
            "tenYOperatingCFGrowthPerShare", "fiveYOperatingCFGrowthPerShare",
            "threeYOperatingCFGrowthPerShare",
            "tenYNetIncomeGrowthPerShare", "fiveYNetIncomeGrowthPerShare",
            "threeYNetIncomeGrowthPerShare",
            "tenYShareholdersEquityGrowthPerShare", "fiveYShareholdersEquityGrowthPerShare",
            "threeYShareholdersEquityGrowthPerShare",
            "tenYDividendperShareGrowthPerShare", "fiveYDividendperShareGrowthPerShare",
            "threeYDividendperShareGrowthPerShare",
            "tenYBottomLineNetIncomeGrowthPerShare", "fiveYBottomLineNetIncomeGrowthPerShare",
            "threeYBottomLineNetIncomeGrowthPerShare",
        ] {
            add(key, .growth, .percent, .ratio, ttm: false)
        }

        // MARK: Derived

        add("fcfMargin", .derived, .percent, .ratio, ttm: true, label: "FCF Margin")
        add("fcfPerShare", .derived, .perShare, .ratio, ttm: false, label: "FCF Per Share")

        return metrics
    }

    // MARK: - Label generation

    private static let labelOverrides: [String: String] = [
        "eps": "EPS",
        "epsDiluted": "EPS (Diluted)",
        "ebitda": "EBITDA",
        "ebit": "EBIT",
        "weightedAverageShsOut": "Weighted Average Shares Outstanding",
        "weightedAverageShsOutDil": "Weighted Average Shares Outstanding (Diluted)",
        "researchAndDevelopmentExpenses": "R&D Expenses",
        "generalAndAdministrativeExpenses": "G&A Expenses",
        "sellingGeneralAndAdministrativeExpenses": "SG&A Expenses",
        "capitalLeaseOblationsCurrent": "Capital Lease Obligations (Current)",
        "propertyPlantEquipmentNet": "Property, Plant & Equipment (Net)",
        "accumulatedOtherComprehensiveIncomeLoss": "Accumulated Other Comprehensive Income/Loss",
        "totalLiabilitiesAndTotalEquity": "Total Liabilities & Total Equity",
        "netCashProvidedByOperatingActivities": "Net Cash from Operating Activities",
        "netCashProvidedByInvestingActivities": "Net Cash from Investing Activities",
        "netCashProvidedByFinancingActivities": "Net Cash from Financing Activities",
        "investmentsInPropertyPlantAndEquipment": "Investments in Property, Plant & Equipment",
        "effectOfForexChangesOnCash": "Effect of Forex Changes on Cash",
        "ebitMargin": "EBIT Margin",
        "ebitdaMargin": "EBITDA Margin",
        "priceToEarningsRatio": "P/E Ratio",
        "priceToEarningsGrowthRatio": "PEG Ratio",
        "forwardPriceToEarningsGrowthRatio": "Forward PEG Ratio",
        "priceToBookRatio": "P/B Ratio",
        "priceToSalesRatio": "P/S Ratio",
        "priceToFreeCashFlowRatio": "Price to FCF Ratio",
        "priceToOperatingCashFlowRatio": "Price to OCF Ratio",
        "netIncomePerEBT": "Net Income per EBT",
        "ebtPerEbit": "EBT per EBIT",
        "ebitgrowth": "EBIT Growth",
        "ebitdaGrowth": "EBITDA Growth",
        "epsgrowth": "EPS Growth",
        "epsdilutedGrowth": "EPS Diluted Growth",
        "rdexpenseGrowth": "R&D Expense Growth",
        "sgaexpensesGrowth": "SG&A Expenses Growth",
        "bookValueperShareGrowth": "Book Value per Share Growth",
        "growthCapitalExpenditure": "Capital Expenditure Growth",
        "freeCashFlowOperatingCashFlowRatio": "FCF to OCF Ratio",
    ]

    static func label(for key: String) -> String {
        if let override = labelOverrides[key] {
            return override
        }

        var working = key
        var prefix = ""
        for (raw, replacement) in [("tenY", "10Y "), ("fiveY", "5Y "), ("threeY", "3Y ")] {
            if working.hasPrefix(raw) {
                prefix = replacement
                working = String(working.dropFirst(raw.count))
                break
            }
        }

        var words: [String] = []
        var current = ""
        for character in working {
            if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            words.append(current)
        }

        let lowercaseWords: Set = ["and", "of", "to", "per", "on", "from", "in"]
        let acronyms: Set = ["cf", "fcf", "ocf", "ebt"]
        let titled = words.enumerated().map { index, word -> String in
            let lowered = word.lowercased()
            if acronyms.contains(lowered) {
                return lowered.uppercased()
            }
            if index > 0, lowercaseWords.contains(lowered) {
                return lowered
            }
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return prefix + titled.joined(separator: " ")
    }
}
