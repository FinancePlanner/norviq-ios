import Foundation
import StockPlanShared

enum StockDetailTab: String, CaseIterable, Identifiable {
    case chart
    case overview
    case statements
    case analysis
    case forecast
    case compare
    case news
    case earnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chart:
            "Chart"
        case .overview:
            "Overview"
        case .statements:
            "Statements"
        case .analysis:
            "Analysis"
        case .forecast:
            "Forecast"
        case .compare:
            "Compare"
        case .news:
            "News"
        case .earnings:
            "Earnings"
        }
    }
}

enum StockProjectionScenarioKind: String, CaseIterable, Identifiable {
    case bear
    case base
    case bull

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bear:
            "Bear"
        case .base:
            "Base"
        case .bull:
            "Bull"
        }
    }

    var subtitle: String {
        switch self {
        case .bear:
            "Lower growth, lower multiple, more conservative outcomes."
        case .base:
            "Most likely operating path using balanced assumptions."
        case .bull:
            "Higher growth, stronger margins, and better exit multiples."
        }
    }
}

enum StockComparisonMetricGroup: String, CaseIterable, Identifiable {
    case mandatory
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mandatory:
            "Mandatory Metrics"
        case .advanced:
            "Advanced Metrics"
        }
    }
}

extension StockComparisonMetricGroup {
    var metrics: [StockComparisonMetric] {
        StockComparisonMetric.allCases.filter { $0.group == self }
    }
}

enum StockMetricValueFormat {
    case multiple
    case percent
    case plain
}

enum StockComparisonMetric: String, CaseIterable, Identifiable {
    case ttmPE
    case forwardPE
    case twoYearForwardPE
    case ttmEPSGrowth
    case currentYearExpectedEPSGrowth
    case nextYearEPSGrowth
    case ttmRevenueGrowth
    case currentYearExpectedRevenueGrowth
    case nextYearRevenueGrowth
    case grossMargin
    case netMargin
    case ttmPEGRatio
    case lastYearEPSGrowth
    case ttmVsNTMEPSGrowth
    case currentQuarterEPSGrowthVsPreviousYear
    case twoYearStackExpectedEPSGrowth
    case lastYearRevenueGrowth
    case ttmVsNTMRevenueGrowth
    case currentQuarterRevenueGrowthVsPreviousYear
    case twoYearStackExpectedRevenueGrowth
    case dcfFairValue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ttmPE:
            "TTM PE"
        case .forwardPE:
            "Forward PE"
        case .twoYearForwardPE:
            "2 Year Forward PE"
        case .ttmEPSGrowth:
            "TTM EPS Growth"
        case .currentYearExpectedEPSGrowth:
            "Current Yr Exp EPS Growth"
        case .nextYearEPSGrowth:
            "Next Year EPS Growth"
        case .ttmRevenueGrowth:
            "TTM Rev Growth"
        case .currentYearExpectedRevenueGrowth:
            "Current Yr Exp Rev Growth"
        case .nextYearRevenueGrowth:
            "Next Year Rev Growth"
        case .grossMargin:
            "Gross Margin"
        case .netMargin:
            "Net Margin"
        case .ttmPEGRatio:
            "TTM PEG Ratio"
        case .lastYearEPSGrowth:
            "Last Year EPS Growth"
        case .ttmVsNTMEPSGrowth:
            "TTM vs NTM EPS Growth"
        case .currentQuarterEPSGrowthVsPreviousYear:
            "Current Quarter EPS Growth vs Previous Year"
        case .twoYearStackExpectedEPSGrowth:
            "2 Year Stack Exp EPS Growth"
        case .lastYearRevenueGrowth:
            "Last Year Rev Growth"
        case .ttmVsNTMRevenueGrowth:
            "TTM vs NTM Rev Growth"
        case .currentQuarterRevenueGrowthVsPreviousYear:
            "Current Quarter Rev Growth vs Previous Year"
        case .twoYearStackExpectedRevenueGrowth:
            "2 Year Stack Exp Rev Growth"
        case .dcfFairValue:
            "DCF Fair Value (Base)"
        }
    }

    var group: StockComparisonMetricGroup {
        switch self {
        case .ttmPE, .forwardPE, .twoYearForwardPE, .ttmEPSGrowth, .currentYearExpectedEPSGrowth,
             .nextYearEPSGrowth, .ttmRevenueGrowth, .currentYearExpectedRevenueGrowth,
             .nextYearRevenueGrowth, .grossMargin, .netMargin, .ttmPEGRatio, .dcfFairValue:
            .mandatory
        case .lastYearEPSGrowth, .ttmVsNTMEPSGrowth, .currentQuarterEPSGrowthVsPreviousYear,
             .twoYearStackExpectedEPSGrowth, .lastYearRevenueGrowth, .ttmVsNTMRevenueGrowth,
             .currentQuarterRevenueGrowthVsPreviousYear, .twoYearStackExpectedRevenueGrowth:
            .advanced
        }
    }

    var format: StockMetricValueFormat {
        switch self {
        case .ttmPE, .forwardPE, .twoYearForwardPE, .ttmPEGRatio:
            .multiple
        case .dcfFairValue:
            .plain
        case .ttmEPSGrowth, .currentYearExpectedEPSGrowth, .nextYearEPSGrowth,
             .ttmRevenueGrowth, .currentYearExpectedRevenueGrowth, .nextYearRevenueGrowth,
             .grossMargin, .netMargin, .lastYearEPSGrowth, .ttmVsNTMEPSGrowth,
             .currentQuarterEPSGrowthVsPreviousYear, .twoYearStackExpectedEPSGrowth,
             .lastYearRevenueGrowth, .ttmVsNTMRevenueGrowth,
             .currentQuarterRevenueGrowthVsPreviousYear, .twoYearStackExpectedRevenueGrowth:
            .percent
        }
    }

    var benchmarkText: String {
        switch self {
        case .ttmPE:
            "Many quality stocks trade at 18x - 28x."
        case .forwardPE:
            "Many quality stocks trade at 16x - 24x."
        case .twoYearForwardPE:
            "Many quality stocks trade at 14x - 22x."
        case .ttmEPSGrowth:
            "Many quality stocks grow EPS at 8% - 18%."
        case .currentYearExpectedEPSGrowth:
            "Many quality stocks grow EPS at 10% - 20%."
        case .nextYearEPSGrowth:
            "Many quality stocks grow EPS at 12% - 24%."
        case .ttmRevenueGrowth:
            "Many quality stocks grow revenue at 6% - 14%."
        case .currentYearExpectedRevenueGrowth:
            "Many quality stocks grow revenue at 7% - 15%."
        case .nextYearRevenueGrowth:
            "Many quality stocks grow revenue at 8% - 16%."
        case .grossMargin:
            "Many quality stocks report 45% - 70% gross margins."
        case .netMargin:
            "Many quality stocks report 15% - 30% net margins."
        case .ttmPEGRatio:
            "Many quality stocks trade around 1.2x - 2.2x PEG."
        case .lastYearEPSGrowth:
            "Many quality stocks delivered 5% - 18% EPS growth."
        case .ttmVsNTMEPSGrowth:
            "Many quality stocks show 2% - 8% EPS acceleration."
        case .currentQuarterEPSGrowthVsPreviousYear:
            "Many quality stocks print 8% - 20% quarterly EPS growth."
        case .twoYearStackExpectedEPSGrowth:
            "Many quality stocks compound EPS at 18% - 35% over two years."
        case .lastYearRevenueGrowth:
            "Many quality stocks delivered 4% - 14% revenue growth."
        case .ttmVsNTMRevenueGrowth:
            "Many quality stocks show 1% - 5% revenue acceleration."
        case .currentQuarterRevenueGrowthVsPreviousYear:
            "Many quality stocks print 5% - 15% quarterly revenue growth."
        case .twoYearStackExpectedRevenueGrowth:
            "Many quality stocks compound revenue at 10% - 22% over two years."
        case .dcfFairValue:
            "Intrinsic value per share using Discounted Cash Flow."
        }
    }
}

struct StockProjectionYear: Identifiable, Equatable {
    var id: Int { year }

    let year: Int
    let revenue: Double
    let revenueGrowth: Double
    let netIncome: Double
    let netIncomeGrowth: Double
    let netMargin: Double
    let eps: Double
    let freeCashFlow: Double?
    let peLowEstimate: Double
    let peHighEstimate: Double
    let sharePriceLow: Double
    let sharePriceHigh: Double
    let cagrLow: Double?
    let cagrHigh: Double?
}

struct StockProjectionScenario: Equatable {
    let kind: StockProjectionScenarioKind
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let years: [StockProjectionYear]
}

public typealias StockMarketSnapshot = QuoteResponse

struct StockComparisonProfile: Identifiable, Equatable {
    var id: String { symbol }

    let symbol: String
    let companyName: String
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let metrics: [StockComparisonMetric: Double]
    let projectionScenarios: [StockProjectionScenarioKind: StockProjectionScenario]
    let dcfBasePrice: Double?
    let dcfBearPrice: Double?
    let dcfBullPrice: Double?
}

